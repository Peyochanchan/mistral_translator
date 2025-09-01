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
        rescue JSON::ParserError
          raise InvalidResponseError, "Invalid JSON in response: #{raw_content}"
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
        # Chercher le JSON dans la réponse (peut être entouré de texte)
        json_match = content.match(/\{.*\}/m)
        json_match&.[](0)
      end

      def extract_target_content(data)
        # Essayer différents chemins possibles pour le contenu traduit
        [
          data.dig("content", "target"),
          data.dig("translation", "target"),
          data["target"],
          data.dig("content", "translated"),
          data["translated"]
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
