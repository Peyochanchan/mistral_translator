# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require_relative "logger"
require_relative "client_helpers"

module MistralTranslator
  class Client
    include ClientHelpers::RequestHandler
    include ClientHelpers::ErrorHandler
    include ClientHelpers::BatchHandler
    include ClientHelpers::LoggingHelper

    def initialize(api_key: nil)
      @api_key = api_key || MistralTranslator.configuration.api_key!
      @base_uri = MistralTranslator.configuration.api_url
      @model = MistralTranslator.configuration.model
      @retry_delays = MistralTranslator.configuration.retry_delays
    end

    def complete(prompt, max_tokens: nil, temperature: nil, context: {})
      ctx = (context || {}).merge(operation: :complete)
      start_time = Time.now
      trigger_translation_start_callback(ctx, prompt)

      response = make_request_with_retry(prompt, max_tokens, temperature, ctx)
      content = extract_content_from_response(response)

      trigger_translation_complete_callback(ctx, prompt, content, start_time)
      content
    rescue JSON::ParserError => e
      handle_json_parse_error(e, ctx)
    rescue NoMethodError => e
      handle_response_structure_error(e, ctx)
    end

    def chat(prompt, max_tokens: nil, temperature: nil, context: {})
      ctx = (context || {}).merge(operation: :chat)
      start_time = Time.now
      trigger_translation_start_callback(ctx, prompt)

      response = make_request_with_retry(prompt, max_tokens, temperature, ctx)
      content = extract_chat_content_from_response(response)

      trigger_translation_complete_callback(ctx, prompt, content, start_time)
      content
    rescue JSON::ParserError => e
      handle_json_parse_error(e, ctx)
    rescue NoMethodError => e
      handle_response_structure_error(e, ctx)
    end

    # Nouvelle méthode pour traduction par batch optimisée
    def translate_batch(requests, batch_size: 5)
      start_time = Time.now
      results = []
      success_count = 0
      error_count = 0

      requests.each_slice(batch_size) do |batch|
        batch_results = process_batch_slice(batch)
        results.concat(batch_results[:results])
        success_count += batch_results[:success_count]
        error_count += batch_results[:error_count]

        # Délai entre les batches pour éviter les rate limits
        sleep(2) unless batch == requests.last(batch_size)
      end

      total_duration = Time.now - start_time
      MistralTranslator.configuration.trigger_batch_complete(
        requests.size,
        total_duration,
        success_count,
        error_count
      )

      results
    end

    private

    def trigger_translation_start_callback(context, prompt)
      MistralTranslator.configuration.trigger_translation_start(
        context[:from_locale],
        context[:to_locale],
        prompt&.length || 0
      )
    end

    def extract_content_from_response(response)
      parsed_response = JSON.parse(response.body)
      content = parsed_response.dig("choices", 0, "message", "content")
      raise InvalidResponseError, "No content in API response" if content.nil? || content.empty?

      content
    end

    def extract_chat_content_from_response(response)
      parsed_response = JSON.parse(response.body)
      parsed_response.dig("choices", 0, "message", "content")
    end

    def trigger_translation_complete_callback(context, prompt, content, start_time)
      duration = Time.now - start_time
      MistralTranslator.configuration.trigger_translation_complete(
        context[:from_locale],
        context[:to_locale],
        prompt&.length || 0,
        content&.length || 0,
        duration
      )
    end

    def handle_json_parse_error(error, context)
      MistralTranslator.configuration.trigger_translation_error(
        context[:from_locale],
        context[:to_locale],
        error,
        context[:attempt] || 0
      )
      message = if context[:operation] == :chat
                  "JSON parse error: #{error.message}"
                else
                  "Invalid JSON in API response: #{error.message}"
                end
      raise InvalidResponseError, message
    end

    def handle_response_structure_error(error, context)
      MistralTranslator.configuration.trigger_translation_error(
        context[:from_locale],
        context[:to_locale],
        error,
        context[:attempt] || 0
      )
      raise InvalidResponseError, "Invalid response structure: #{error.message}"
    end
  end
end
