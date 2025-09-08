# frozen_string_literal: true

module MistralTranslator
  class ResponseParser
    class << self
      def parse_translation_response(raw_content)
        return nil if raw_content.nil? || raw_content.empty?

        begin
          # Extraire le JSON de la réponse (peut contenir du texte avant/après)
          json_content = extract_json_from_content(raw_content)
          return nil unless json_content

          # Parser le JSON
          translation_data = JSON.parse(json_content)

          # Extraire le contenu traduit selon différents formats possibles
          translated_text = extract_target_content(translation_data)

          # Vérifier si la traduction est vide et lever l'erreur appropriée
          if translated_text.nil? || translated_text.empty?
            raise EmptyTranslationError, "Empty translation received from API"
          end

          {
            original: extract_source_content(translation_data),
            translated: translated_text,
            metadata: translation_data["metadata"] || {}
          }
        rescue JSON::ParserError => e
          # Log sécurisé des détails d'erreur (sans exposer de données sensibles)
          error_details = {
            error_message: e.message,
            raw_content_length: raw_content&.length,
            json_content_length: json_content&.length,
            has_json_content: !json_content.nil?
          }
          raise InvalidResponseError, "Invalid JSON in response: #{e.message}. Details: #{error_details}"
        rescue EmptyTranslationError
          raise # Re-raise EmptyTranslationError
        rescue StandardError => e
          raise InvalidResponseError, "Error processing response: #{e.message}"
        end
      end

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
          raise InvalidResponseError, "Invalid JSON in summary response: #{raw_content}"
        rescue EmptyTranslationError
          raise # Re-raise EmptyTranslationError
        rescue StandardError => e
          raise InvalidResponseError, "Error processing summary response: #{e.message}"
        end
      end

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
        # Chercher le premier { et essayer de trouver le } correspondant
        start_pos = text.index("{")
        return nil unless start_pos

        brace_count = 0
        in_string = false
        escape_next = false
        max_iterations = 100_000 # Limite pour éviter les boucles infinies
        iterations = 0

        (start_pos...text.length).each do |i|
          iterations += 1
          if iterations > max_iterations
            raise InvalidResponseError, "JSON parsing exceeded maximum iterations (possible malformed JSON)"
          end

          char = text[i]

          if escape_next
            escape_next = false
            next
          end

          if char == "\\"
            escape_next = true
            next
          end

          if char == '"' && !escape_next
            in_string = !in_string
            next
          end

          next if in_string

          if char == "{"
            brace_count += 1
          elsif char == "}"
            brace_count -= 1
            return text[start_pos..i] if brace_count.zero?
          end
        end

        nil
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
