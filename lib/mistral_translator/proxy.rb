# frozen_string_literal: true

require "uri"

module MistralTranslator
  # Proxy HTTP(S) optionnel pour joindre l'API. Les identifiants du proxy
  # ne figurent jamais dans les messages d'erreur.
  module Proxy
    SCHEMES = %w[http https].freeze

    class << self
      # nil : pas de proxy ; URI ou String : ce proxy ; :env : variables d'environnement
      def validate!(setting)
        return if setting.nil? || setting == :env

        parse!(setting)
      end

      # URI du proxy à utiliser pour joindre host, ou nil
      def resolve(setting, host:, env: ENV)
        return nil if setting.nil?
        return from_env(host, env) if setting == :env

        parse!(setting)
      end

      private

      # net-http-persistent ne lit que HTTP_PROXY : HTTPS_PROXY est lu ici, en priorité.
      def from_env(host, env)
        value = env_value(env, "https_proxy") || env_value(env, "http_proxy")
        return nil if value.nil? || bypassed?(host, env_value(env, "no_proxy"))

        parse!(value)
      end

      def env_value(env, name)
        value = env[name] || env[name.upcase]
        value unless value.nil? || value.strip.empty?
      end

      def bypassed?(host, no_proxy)
        return false if no_proxy.nil?

        no_proxy.split(",").map { |entry| entry.strip.downcase.sub(/:\d+\z/, "") }.any? do |entry|
          next false if entry.empty?
          next true if entry == "*"

          domain = entry.delete_prefix("*").delete_prefix(".")
          host == domain || host.end_with?(".#{domain}")
        end
      end

      def parse!(value)
        uri = value.is_a?(URI::Generic) ? value : URI.parse(value.to_s)
        return uri if SCHEMES.include?(uri.scheme) && uri.host && !uri.host.empty?

        raise ConfigurationError, "Invalid proxy: expected an http(s) URL with a host"
      rescue URI::InvalidURIError
        raise ConfigurationError, "Invalid proxy: malformed URL"
      end
    end
  end
end
