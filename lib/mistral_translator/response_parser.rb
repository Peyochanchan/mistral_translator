# frozen_string_literal: true

require_relative "logger"

module MistralTranslator
  class ResponseParser
    class << self
      def parse_translation_response(raw_content)
        return nil if raw_content.nil? || raw_content.empty?

        begin
          json_content = extract_json_from_content(raw_content)
          return nil unless json_content

          translation_data = parse_json_content(json_content)
          translated_text = extract_target_content(translation_data)
          validate_translation_content(translated_text)

          build_translation_result(translation_data, translated_text)
        rescue JSON::ParserError => e
          handle_json_parse_error(e, raw_content, json_content)
        rescue EmptyTranslationError
          raise # Re-raise EmptyTranslationError
        rescue StandardError => e
          raise InvalidResponseError, "Error processing response: #{e.message}"
        end
      end

      def parse_quality_check_response(raw_content)
        return { translation: nil, quality_check: {}, metadata: {} } if raw_content.nil? || raw_content.empty?

        json_content = extract_json_from_content(raw_content)
        raise InvalidResponseError, "Invalid JSON in quality check response" unless json_content

        data = JSON.parse(json_content)

        translation = extract_target_content(data)
        quality = data["quality_check"] || data.dig("metadata", "quality_check") || {}
        {
          translation: translation,
          quality_check: quality,
          metadata: data["metadata"] || {}
        }
      rescue JSON::ParserError
        raise InvalidResponseError, "Invalid JSON in quality check response"
      rescue StandardError => e
        raise InvalidResponseError, "Error processing quality check response: #{e.message}"
      end

      def parse_json_content(json_content)
        JSON.parse(json_content)
      rescue JSON::ParserError
        # Pass 1: join quoted string segments split by backslash-newline
        # pattern: " ... " \\<newline> " ... "
        joined_segments = json_content.gsub(/"\s*\\\r?\n\s*"/, "")
        begin
          JSON.parse(joined_segments)
        rescue JSON::ParserError
          # Pass 2: remove any remaining backslash-newline continuations
          removed_continuations = joined_segments.gsub(/\\\s*\r?\n\s*/, "")
          JSON.parse(removed_continuations)
        end
      end

      def validate_translation_content(translated_text)
        return unless translated_text.nil? || translated_text.empty?

        raise EmptyTranslationError, "Empty translation received from API"
      end

      def build_translation_result(translation_data, translated_text)
        {
          original: extract_source_content(translation_data),
          translated: translated_text,
          metadata: translation_data["metadata"] || {}
        }
      end

      def handle_json_parse_error(error, raw_content, json_content)
        error_details = {
          error_message: error.message,
          raw_content_length: raw_content&.length,
          json_content_length: json_content&.length,
          has_json_content: !json_content.nil?
        }
        Logger.debug_if_verbose(
          "JSON parse failed: #{error.message} raw_len=#{error_details[:raw_content_length]} " \
          "json_len=#{error_details[:json_content_length]} snippet=#{raw_content&.slice(0, 120)}",
          sensitive: false
        )
        raise InvalidResponseError, "Invalid JSON in response: #{error.message}. Details: #{error_details}"
      end

      # rubocop:disable Metrics/PerceivedComplexity
      def parse_summary_response(raw_content)
        return nil if raw_content.nil? || raw_content.empty?

        begin
          json_content = extract_json_from_content(raw_content)
          return nil unless json_content

          summary_data = JSON.parse(json_content)
          summary_text = extract_target_content(summary_data)

          raise EmptyTranslationError, "Empty summary received" if summary_text.nil? || summary_text.empty?

          {
            original: extract_source_content(summary_data),
            summary: summary_text,
            metadata: summary_data["metadata"] || {}
          }
        rescue JSON::ParserError
          # Fallback: si ce n'est pas du JSON, essayer d'utiliser le texte brut s'il a du contenu
          text = raw_content.to_s.strip
          raise InvalidResponseError, "Invalid JSON in summary response: #{raw_content}" if text.empty?

          {
            original: nil,
            summary: text,
            metadata: { "operation" => "summarization", "fallback" => true }
          }
        rescue EmptyTranslationError
          raise # Re-raise EmptyTranslationError
        rescue StandardError => e
          raise InvalidResponseError, "Error processing summary response: #{e.message}"
        end
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def parse_bulk_translation_response(raw_content)
        return [] if raw_content.nil? || raw_content.empty?

        begin
          json_content = extract_json_from_content(raw_content)
          raise InvalidResponseError, "Invalid JSON in bulk response: #{raw_content}" unless json_content

          bulk_data = JSON.parse(json_content)
          translations = bulk_data["translations"]

          raise InvalidResponseError, "No translations array in response" unless translations.is_a?(Array)

          translations.map do |translation|
            {
              index: translation["index"],
              original: translation["source"],
              translated: translation["target"]
            }
          end
        rescue JSON::ParserError
          raise InvalidResponseError, "Invalid JSON in bulk response: #{raw_content}"
        rescue StandardError => e
          # Ne pas wrapper l'erreur "No translations array in response"
          raise e if e.message == "No translations array in response"

          raise InvalidResponseError, "Error processing bulk response: #{e.message}"
        end
      end

      private

      def extract_json_from_content(content)
        return nil if content.nil? || content.empty?

        # Limiter la taille pour éviter les attaques DoS
        max_content_size = 1_000_000 # 1MB max
        if content.length > max_content_size
          raise InvalidResponseError, "Response content too large (#{content.length} bytes, max: #{max_content_size})"
        end

        # Essayer d'abord de parser directement le contenu comme JSON
        begin
          JSON.parse(content)
          content
        rescue JSON::ParserError
          # Si ça échoue, chercher le JSON dans la réponse (peut être entouré de texte)
          # Utiliser une approche plus robuste pour les JSON complexes
          find_json_in_text(content)
        end
      end

      def find_json_in_text(text)
        start_pos = find_json_start(text)
        return nil unless start_pos

        parse_json_until_end(text, start_pos)
      end

      def find_json_start(text)
        text.index("{")
      end

      def parse_json_until_end(text, start_pos)
        parser_state = JsonParserState.new
        max_iterations = 100_000

        (start_pos...text.length).each do |i|
          parser_state.increment_iterations
          if parser_state.iterations > max_iterations
            raise InvalidResponseError,
                  "JSON parsing exceeded maximum iterations"
          end

          char = text[i]
          parser_state.process_character(char)

          return text[start_pos..i] if parser_state.found_complete_json?
        end

        nil
      end

      # Helper class pour gérer l'état du parsing JSON
      class JsonParserState
        attr_reader :iterations

        def initialize
          @brace_count = 0
          @in_string = false
          @escape_next = false
          @iterations = 0
        end

        def increment_iterations
          @iterations += 1
        end

        def process_character(char)
          return handle_escape_character if @escape_next
          return handle_backslash_character if char == "\\"
          return handle_quote_character(char) if char == '"' && !@escape_next
          return if @in_string

          handle_brace_character(char)
        end

        def handle_escape_character
          @escape_next = false
        end

        def handle_backslash_character
          @escape_next = true
        end

        def handle_quote_character(_char)
          @in_string = !@in_string
        end

        def handle_brace_character(char)
          if char == "{"
            @brace_count += 1
          elsif char == "}"
            @brace_count -= 1
          end
        end

        def found_complete_json?
          @brace_count.zero?
        end
      end

      def extract_target_content(data)
        # Essayer différents chemins possibles pour le contenu traduit
        [
          data.dig("content", "target"),
          data.dig("translation", "target"),
          data["target"],
          data.dig("content", "translated"),
          data["translated"],
          data.dig("content", "summary"),
          data["summary"]
        ].find { |item| item && !item.to_s.empty? }
      end

      def extract_source_content(data)
        # Essayer différents chemins possibles pour le contenu source
        [
          data.dig("content", "source"),
          data.dig("translation", "source"),
          data["source"],
          data.dig("content", "original"),
          data["original"]
        ].find { |item| item && !item.to_s.empty? }
      end
    end
  end
end
