# frozen_string_literal: true

require_relative "logger"

module MistralTranslator
  class ResponseParser
    # Emplacements possibles du texte traduit ou résumé, par ordre de priorité
    TARGET_PATHS = [
      %w[content target], %w[translation target], %w[target],
      %w[content translated], %w[translated],
      %w[content summary], %w[summary]
    ].freeze

    SOURCE_PATHS = [
      %w[content source], %w[translation source], %w[source],
      %w[content original], %w[original]
    ].freeze

    # Garde-fous contre les réponses démesurées
    MAX_CONTENT_SIZE = 1_000_000
    MAX_SCAN_LENGTH = 100_000
    BRACE_DEPTH = { "{" => 1, "}" => -1 }.freeze

    class << self
      def parse_translation_response(raw_content)
        return nil if raw_content.nil? || raw_content.empty?

        with_response_errors("translation", raw_content) do
          data = parse_response_json(raw_content, "translation")
          translated_text = target_text!(data, "Empty translation received from API", raw_content)

          build_translation_result(data, translated_text)
        end
      end

      def parse_quality_check_response(raw_content)
        return { translation: nil, quality_check: {}, metadata: {} } if raw_content.nil? || raw_content.empty?

        with_response_errors("quality check", raw_content) do
          data = parse_response_json(raw_content, "quality check")

          {
            translation: target_text!(data, "Empty translation received from API", raw_content),
            quality_check: data["quality_check"] || value_at(data, %w[metadata quality_check]) || {},
            metadata: metadata_of(data)
          }
        end
      end

      def parse_summary_response(raw_content)
        return nil if raw_content.nil? || raw_content.empty?

        with_response_errors("summary", raw_content) do
          data = parse_response_json(raw_content, "summary")

          {
            original: extract_source_content(data),
            summary: target_text!(data, "Empty summary received", raw_content),
            metadata: metadata_of(data)
          }
        end
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

      def build_translation_result(translation_data, translated_text)
        {
          original: extract_source_content(translation_data),
          translated: translated_text,
          metadata: metadata_of(translation_data)
        }
      end

      private

      # Les erreurs Ruby (JSON::ParserError, NoMethodError, TypeError…) citent la réponse dans
      # leur message : ni ce message ni l'erreur d'origine (cause) ne sont repris.
      # La réponse reste accessible au code appelant via InvalidResponseError#raw_response.
      def with_response_errors(label, raw_content)
        yield
      rescue EmptyTranslationError, InvalidResponseError
        raise
      rescue StandardError => e
        raise InvalidResponseError.new("Error processing #{label} response (#{e.class})", raw_content), cause: nil
      end

      # Le mode JSON de l'API renvoie un objet seul, lu tel quel. Sinon, on lit le premier objet
      # trouvé dans le texte, en réparant les continuations de ligne.
      def parse_response_json(raw_content, label)
        ensure_content_size!(raw_content)
        data = parse_whole_or_embedded(raw_content, label)
        raise InvalidResponseError.new("Unexpected JSON in #{label} response", raw_content) unless data.is_a?(Hash)

        data
      end

      def ensure_content_size!(content)
        return if content.length <= MAX_CONTENT_SIZE

        raise InvalidResponseError, "Response content too large (#{content.length} bytes, max: #{MAX_CONTENT_SIZE})"
      end

      def parse_whole_or_embedded(raw_content, label)
        JSON.parse(raw_content)
      rescue JSON::ParserError
        json_content = find_json_in_text(raw_content)
        raise InvalidResponseError.new("No JSON in #{label} response", raw_content), cause: nil unless json_content

        parse_embedded_json(json_content, raw_content, label)
      end

      def parse_embedded_json(json_content, raw_content, label)
        parse_json_content(json_content)
      rescue JSON::ParserError
        details = "raw_len=#{raw_content.length} json_len=#{json_content.length}"
        Logger.debug_if_verbose("JSON parse failed: #{details}", sensitive: false)
        raise InvalidResponseError.new("Invalid JSON in #{label} response (#{details})", raw_content), cause: nil
      end

      # Le premier objet du texte, de sa première accolade à celle qui la referme.
      def find_json_in_text(text)
        start = text.index("{")
        finish = closing_brace_index(text, start) if start
        text[start..finish] if finish
      end

      # Les accolades des chaînes ne comptent pas ; le parcours est plafonné.
      def closing_brace_index(text, start)
        depth = 0
        in_string = false
        escaped = false

        (start...text.length).each do |index|
          ensure_scan_length!(index - start)
          char = text[index]

          if escaped
            escaped = false
          elsif char == "\\"
            escaped = true
          elsif char == '"'
            in_string = !in_string
          elsif !in_string
            depth += BRACE_DEPTH.fetch(char, 0)
            return index if depth.zero?
          end
        end

        nil
      end

      def ensure_scan_length!(scanned)
        return if scanned < MAX_SCAN_LENGTH

        raise InvalidResponseError, "JSON parsing exceeded maximum iterations", cause: nil
      end

      # Le texte traduit ou résumé : toujours une String non vide, jamais un objet ou un tableau.
      def target_text!(data, empty_message, raw_content)
        target = find_target(data)
        nested = nested_response(target)
        target = find_target(nested) || "" if nested && target_candidates(nested).any?

        unless target.nil? || target.is_a?(String)
          raise InvalidResponseError.new("Unexpected target in response", raw_content)
        end
        raise EmptyTranslationError, empty_message if target.to_s.strip.empty?

        target
      end

      def find_target(data)
        target_candidates(data).find { |item| !(item.respond_to?(:empty?) && item.empty?) }
      end

      def target_candidates(data)
        TARGET_PATHS.filter_map { |path| value_at(data, path) }
      end

      # Comme Hash#dig, mais un nœud intermédiaire qui n'est pas un objet donne nil au lieu de TypeError.
      def value_at(data, path)
        path.reduce(data) { |node, key| node.is_a?(Hash) ? node[key] : nil }
      end

      def metadata_of(data)
        data["metadata"].is_a?(Hash) ? data["metadata"] : {}
      end

      # Le modèle renvoie parfois l'objet de réponse attendu, tel quel ou sérialisé, dans "target" :
      # on y cherche la cible un niveau plus bas. Un JSON sans clé connue reste une traduction.
      def nested_response(target)
        return target if target.is_a?(Hash)
        return nil unless target.is_a?(String) && target.lstrip.start_with?("{")

        parsed = JSON.parse(target)
        parsed if parsed.is_a?(Hash)
      rescue JSON::ParserError
        nil
      end

      def extract_source_content(data)
        SOURCE_PATHS.map { |path| value_at(data, path) }.find { |item| item.is_a?(String) && !item.empty? }
      end
    end
  end
end
