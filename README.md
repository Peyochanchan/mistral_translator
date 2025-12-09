# MistralTranslator

Ruby gem for AI-powered translation and text summarization using Mistral AI API, with advanced Rails support.

[![Ruby](https://img.shields.io/badge/ruby-%23CC342D.svg?style=flat&logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![Gem Version](https://img.shields.io/badge/gem%20version-0.3.0-blue.svg)](https://rubygems.org/gems/mistral_translator)
[![RSpec](https://img.shields.io/badge/tested%20with-RSpec-red.svg)](https://rspec.info/)
[![RuboCop](https://img.shields.io/badge/code%20style-RuboCop-brightgreen.svg)](https://rubocop.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Quick Start

```ruby
# Installation
gem 'mistral_translator'

# Configuration
MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']
end

# Basic usage
MistralTranslator.translate("Bonjour le monde", from: "fr", to: "en")
# => "Hello world"
```

## Key Features

- **Smart translation** with context and custom glossaries
- **Native Rails integration** (Mobility, Globalize, I18n attributes)
- **Batch processing** for high-volume translations
- **Multi-level summarization** with translation
- **Robust error handling** with automatic retry and fallback
- **Complete monitoring** with metrics and callbacks
- **Thread-safe & concurrent** with connection pooling ([docs](https://peyochanchan.github.io/mistral_translator/#/advanced-usage/concurrent-async))
- **Built-in rate limiting** and security

## Supported Languages

`fr` `en` `es` `pt` `de` `it` `nl` `ru` `mg` `ja` `ko` `zh` `ar`

## Installation

Add to your Gemfile:

```ruby
gem 'mistral_translator'
```

Then run:

```bash
bundle install
```

### API Key Setup

Get your API key from [Mistral AI Console](https://console.mistral.ai/) and configure it:

```ruby
# Environment variable (recommended)
export MISTRAL_API_KEY="your_api_key_here"

# Or in Rails config/initializers/mistral_translator.rb
MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']
  config.enable_metrics = Rails.env.production?
end
```

## Basic Usage Examples

### Simple Translation

```ruby
# Basic translation
result = MistralTranslator.translate("Bonjour", from: "fr", to: "en")
# => "Hello"

# With context for better accuracy
result = MistralTranslator.translate(
  "Le produit est disponible",
  from: "fr",
  to: "en",
  context: "E-commerce website"
)
# => "The product is available"

# With custom glossary
result = MistralTranslator.translate(
  "Notre API est performante",
  from: "fr",
  to: "en",
  glossary: { "API" => "API" }  # Preserve technical terms
)
# => "Our API is high-performing"
```

### Auto-Detection

```ruby
# Automatic source language detection
MistralTranslator.translate_auto("¡Hola mundo!", to: "fr")
# => "Salut le monde !"
```

### Batch Processing

```ruby
texts = ["Bonjour", "Merci", "Au revoir"]
results = MistralTranslator.translate_batch(texts, from: "fr", to: "en")
# => {0 => "Hello", 1 => "Thank you", 2 => "Goodbye"}
```

### Text Summarization

```ruby
long_text = "Ruby on Rails is a web framework..."

# Simple summary
summary = MistralTranslator.summarize(long_text, language: "en", max_words: 50)

# Summary with translation
summary = MistralTranslator.summarize_and_translate(
  long_text,
  from: "en",
  to: "fr",
  max_words: 100
)
```

### Rails Integration

```ruby
# With Mobility
class Article < ApplicationRecord
  extend Mobility
  translates :title, :content, backend: :table

  def translate_to_all_languages!
    MistralTranslator::RecordTranslation.translate_mobility_record(
      self,
      [:title, :content],
      source_locale: I18n.locale
    )
  end
end

# Usage
article = Article.create!(title_fr: "Titre français", content_fr: "Contenu...")
article.translate_to_all_languages!
```

## Configuration Options

```ruby
MistralTranslator.configure do |config|
  # Required
  config.api_key = ENV['MISTRAL_API_KEY']

  # Optional
  config.model = "mistral-small"                    # AI model to use
  config.retry_delays = [1, 2, 4, 8, 16]          # Retry delays in seconds
  config.enable_metrics = true                     # Enable performance metrics

  # Callbacks for monitoring
  config.on_translation_complete = ->(from, to, orig_len, trans_len, duration) {
    Rails.logger.info "Translation #{from}→#{to} completed in #{duration.round(2)}s"
  }

  config.on_translation_error = ->(from, to, error, attempt, timestamp) {
    Rails.logger.error "Translation failed: #{error.message} (attempt #{attempt})"
  }
end
```

## Error Handling

```ruby
begin
  result = MistralTranslator.translate("Hello", from: "en", to: "fr")
rescue MistralTranslator::RateLimitError
  # Rate limit hit - automatic retry with backoff
  retry
rescue MistralTranslator::AuthenticationError
  # Invalid API key
  Rails.logger.error "Check your Mistral API key"
rescue MistralTranslator::UnsupportedLanguageError => e
  # Language not supported
  Rails.logger.error "Language '#{e.language}' not supported"
rescue MistralTranslator::Error => e
  # General error handling
  Rails.logger.error "Translation failed: #{e.message}"
end
```

## Performance Monitoring

```ruby
# Enable metrics
MistralTranslator.configure { |c| c.enable_metrics = true }

# View metrics
metrics = MistralTranslator.metrics
puts "Total translations: #{metrics[:total_translations]}"
puts "Average time: #{metrics[:average_translation_time]}s"
puts "Error rate: #{metrics[:error_rate]}%"
```

## 📖 Complete Documentation

**For comprehensive guides, advanced usage, and Rails integration examples:**

### 🌐 [**Full Documentation Website**](https://peyochanchan.github.io/mistral_translator/)

The complete documentation includes:

- **Getting Started Guide** - Step-by-step tutorials
- **Advanced Usage** - Context, glossaries, batch processing, monitoring
- **Rails Integration** - Mobility, Globalize, jobs, controllers
- **API Reference** - Complete method documentation
- **Examples** - Ready-to-use code samples
- **Error Handling** - Comprehensive error management strategies

### Quick Links

- [Installation & Setup](https://peyochanchan.github.io/mistral_translator/#/installation)
- [Rails Integration Guide](https://peyochanchan.github.io/mistral_translator/#/rails-integration/setup)
- [API Methods Reference](https://peyochanchan.github.io/mistral_translator/#/api-reference/methods)
- [Error Handling Guide](https://peyochanchan.github.io/mistral_translator/#/api-reference/errors)
- [Monitoring Setup](https://peyochanchan.github.io/mistral_translator/#/advanced-usage/monitoring)

## Requirements

- Ruby 3.2+
- Mistral AI API key
- Rails 6.0+ (optional, for Rails integration features)

## Testing

```bash
# Install dependencies
bundle install

# Run all unit tests (no API key required)
bundle exec rspec spec/mistral_translator/

# Run all tests with documentation format
bundle exec rspec --format documentation
```

### Integration Tests

Integration tests require a real Mistral API key. **Never commit API keys to version control.**

```bash
# Set API key via environment variable (recommended)
export MISTRAL_API_KEY="your_api_key_here"

# Run integration tests
bundle exec rspec spec/integration/

**Security Note:** Use a dedicated test API key with limited quotas for integration testing.
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## License

MIT License. See [LICENSE](LICENSE.txt) for details.

## Support

- 📖 [Documentation](https://peyochanchan.github.io/mistral_translator/)
- 🐛 [Issues](../../issues)
- 📧 Support: Create an issue for help

### ☕ Support the Project

If this gem helps you, consider supporting its development:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/peyochanchan)

---

Built with Ruby ❤️ by [@peyochanchan](https://github.com/peyochanchan)

```

```
