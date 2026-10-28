# frozen_string_literal: true

require "uri"

module MistralTranslator
  # Proxy HTTP optionnel pour joindre l'API. Les identifiants du proxy
  # ne figurent jamais dans les messages d'erreur.
  module Proxy
    # net-http-persistent ignore le schéma du proxy et lui parle toujours en clair :
    # un proxy https:// enverrait ses identifiants sans chiffrement. Le flux vers
    # l'API reste chiffré de bout en bout (CONNECT puis TLS).
    SCHEME = "http"
    API_PORT = 443

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

      # Une variable vide, en minuscules, ne masque pas sa version en majuscules.
      def env_value(env, name)
        [env[name], env[name.upcase]].map { |value| value.to_s.strip }.find { |value| !value.empty? }
      end

      def bypassed?(host, no_proxy)
        return false if no_proxy.nil?

        no_proxy.split(",").any? { |entry| no_proxy_match?(host.downcase, entry.strip.downcase) }
      end

      # Comme curl : "*", un domaine et ses sous-domaines, avec ou sans point ou "*." initial.
      # Une entrée avec un port ne vaut que pour le port de l'API.
      def no_proxy_match?(host, entry)
        return false if entry.empty?
        return true if entry == "*"

        domain, port = entry.split(":", 2)
        return false if port && port.to_i != API_PORT

        domain = domain.delete_prefix("*").delete_prefix(".")
        host == domain || host.end_with?(".#{domain}")
      end

      def parse!(value)
        uri = URI.parse(value.to_s)
        return uri if uri.is_a?(URI::HTTP) && uri.scheme == SCHEME && uri.host && !uri.host.empty?

        raise ConfigurationError, "Invalid proxy: expected an http:// URL with a host"
      rescue URI::InvalidURIError
        raise ConfigurationError, "Invalid proxy: malformed URL", cause: nil
      end
    end
  end
end
