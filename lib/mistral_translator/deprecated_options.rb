# frozen_string_literal: true

module MistralTranslator
  # Options de configuration obsolètes, retirées en 1.0 : ssl_timeout a toujours réglé
  # l'ouverture de la connexion, default_max_tokens et default_temperature n'ont jamais été lus.
  module DeprecatedOptions
    def ssl_timeout
      deprecated(:ssl_timeout, "use open_timeout")
      open_timeout
    end

    def ssl_timeout=(seconds)
      deprecated(:ssl_timeout, "use open_timeout")
      self.open_timeout = seconds
    end

    def default_max_tokens
      deprecated(:default_max_tokens, "it has no effect")
      @default_max_tokens
    end

    def default_max_tokens=(value)
      deprecated(:default_max_tokens, "it has no effect")
      @default_max_tokens = value
    end

    def default_temperature
      deprecated(:default_temperature, "it has no effect")
      @default_temperature
    end

    def default_temperature=(value)
      deprecated(:default_temperature, "it has no effect")
      @default_temperature = value
    end

    private

    # L'avertissement désigne la ligne de l'appelant, pas celle de la gem
    def deprecated(name, advice)
      Kernel.warn("[MistralTranslator] config.#{name} is deprecated and will be removed in 1.0: #{advice}",
                  uplevel: 2)
    end
  end
end
