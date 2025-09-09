#!/usr/bin/env ruby
# frozen_string_literal: true

# Exemple de configuration complète de monitoring pour MistralTranslator
# Usage: ruby examples/monitoring-setup.rb

$stdout.sync = true
require "json"
require "fileutils"
require "time"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "mistral_translator"

# === SETUP 1: Configuration de base avec métriques ===

puts "=== MistralTranslator Monitoring Setup ==="

# Configuration complète
MistralTranslator.configure do |config|
  config.api_key = ENV["MISTRAL_API_KEY"] || "your_api_key_here"
  config.enable_metrics = true
  config.retry_delays = [1, 2, 4, 8, 16]

  # Callbacks de monitoring
  config.on_translation_start = lambda { |from, to, length, timestamp|
    puts "🚀 [#{timestamp}] Translation #{from}→#{to} starting (#{length} chars)"
  }

  config.on_translation_complete = lambda { |from, to, orig_len, trans_len, duration|
    puts "✅ Translation #{from}→#{to} completed in #{duration.round(3)}s"
    puts "   Efficiency: #{(trans_len.to_f / orig_len).round(2)} chars/char"
  }

  config.on_translation_error = lambda { |from, to, error, attempt, timestamp|
    puts "❌ [#{timestamp}] Translation #{from}→#{to} failed (attempt #{attempt}): #{error.message}"
  }

  config.on_rate_limit = lambda { |from, to, wait_time, attempt, timestamp|
    puts "⏳ [#{timestamp}] Rate limit #{from}→#{to}, waiting #{wait_time}s (attempt #{attempt})"
  }

  config.on_batch_complete = lambda { |size, duration, success, errors|
    puts "📦 Batch completed: #{success}/#{size} success in #{duration.round(2)}s (#{errors} errors)"
  }
end

# === CLASSE: Collecteur de métriques avancé ===

class TranslationMetricsCollector
  CallbackSet = Struct.new(:start, :complete, :error, :rate_limit)
  def initialize
    @stats = {
      translations: 0,
      errors: 0,
      rate_limits: 0,
      total_duration: 0.0,
      total_chars_input: 0,
      total_chars_output: 0,
      by_language: Hash.new(0),
      error_types: Hash.new(0),
      hourly_stats: Hash.new { |h, k| h[k] = { count: 0, errors: 0 } }
    }
    @start_time = Time.now
    setup_callbacks!
  end

  def setup_callbacks!
    originals = fetch_original_callbacks

    MistralTranslator.configure do |config|
      assign_wrapped_callbacks(config, originals)
    end
  end

  def fetch_original_callbacks
    config = MistralTranslator.configuration
    CallbackSet.new(
      config.on_translation_start,
      config.on_translation_complete,
      config.on_translation_error,
      config.on_rate_limit
    )
  end

  def assign_wrapped_callbacks(config, originals)
    config.on_translation_start = lambda { |from, to, length, timestamp|
      originals.start&.call(from, to, length, timestamp)
      on_translation_start(from, to, length, timestamp)
    }

    config.on_translation_complete = lambda { |from, to, orig_len, trans_len, duration|
      originals.complete&.call(from, to, orig_len, trans_len, duration)
      on_translation_complete(from, to, orig_len, trans_len, duration)
    }

    config.on_translation_error = lambda { |from, to, error, attempt, timestamp|
      originals.error&.call(from, to, error, attempt, timestamp)
      on_translation_error(from, to, error, attempt, timestamp)
    }

    config.on_rate_limit = lambda { |from, to, wait_time, attempt, timestamp|
      originals.rate_limit&.call(from, to, wait_time, attempt, timestamp)
      on_rate_limit(from, to, wait_time, attempt, timestamp)
    }
  end

  def on_translation_start(_from, _to, length, timestamp)
    hour_key = timestamp.strftime("%Y-%m-%d %H:00")
    @stats[:hourly_stats][hour_key][:count] += 1
    @stats[:total_chars_input] += length
  end

  def on_translation_complete(from, to, _orig_len, trans_len, duration)
    @stats[:translations] += 1
    @stats[:total_duration] += duration
    @stats[:total_chars_output] += trans_len
    @stats[:by_language]["#{from}_to_#{to}"] += 1
  end

  def on_translation_error(_from, _to, error, _attempt, timestamp)
    @stats[:errors] += 1
    @stats[:error_types][error.class.name] += 1

    hour_key = timestamp.strftime("%Y-%m-%d %H:00")
    @stats[:hourly_stats][hour_key][:errors] += 1
  end

  def on_rate_limit(_from, _to, _wait_time, _attempt, _timestamp)
    @stats[:rate_limits] += 1
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
  def report
    uptime = Time.now - @start_time

    puts "\n#{"=" * 50}"
    puts "📊 TRANSLATION METRICS REPORT"
    puts "=" * 50

    # Statistiques globales
    puts "⏱️  Uptime: #{uptime.round(2)}s"
    puts "📝 Translations: #{@stats[:translations]}"
    puts "❌ Errors: #{@stats[:errors]} (#{error_rate}%)"
    puts "⏳ Rate limits: #{@stats[:rate_limits]}"

    # Performance
    if @stats[:translations].positive?
      avg_duration = @stats[:total_duration] / @stats[:translations]
      puts "⚡ Avg duration: #{avg_duration.round(3)}s per translation"
      puts "📊 Throughput: #{(@stats[:translations] / uptime).round(2)} translations/sec"
    end

    # Caractères
    puts "📄 Input chars: #{@stats[:total_chars_input]}"
    puts "📄 Output chars: #{@stats[:total_chars_output]}"
    if @stats[:total_chars_input].positive?
      expansion = @stats[:total_chars_output].to_f / @stats[:total_chars_input]
      puts "📈 Text expansion: #{expansion.round(2)}x"
    end

    # Top langues
    if @stats[:by_language].any?
      puts "\n🌐 Top language pairs:"
      @stats[:by_language].sort_by { |_, count| -count }.first(5).each do |pair, count|
        percentage = (count.to_f / @stats[:translations] * 100).round(1)
        puts "   #{pair.gsub("_to_", " → ")}: #{count} (#{percentage}%)"
      end
    end

    # Top erreurs
    if @stats[:error_types].any?
      puts "\n❌ Error breakdown:"
      @stats[:error_types].each do |error_type, count|
        percentage = (count.to_f / @stats[:errors] * 100).round(1)
        puts "   #{error_type}: #{count} (#{percentage}%)"
      end
    end

    # Statistiques horaires
    if @stats[:hourly_stats].any?
      puts "\n🕐 Activity by hour (last 5):"
      @stats[:hourly_stats].sort_by { |hour, _| hour }.last(5).each do |hour, stats|
        error_rate = stats[:count].positive? ? (stats[:errors].to_f / stats[:count] * 100).round(1) : 0
        puts "   #{hour}: #{stats[:count]} translations, #{stats[:errors]} errors (#{error_rate}%)"
      end
    end

    puts "=" * 50
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity

  def error_rate
    return 0 if @stats[:translations].zero?

    (@stats[:errors].to_f / (@stats[:translations] + @stats[:errors]) * 100).round(1)
  end

  def health_status
    if error_rate > 20
      { status: :critical, message: "High error rate: #{error_rate}%" }
    elsif error_rate > 10
      { status: :warning, message: "Elevated error rate: #{error_rate}%" }
    elsif @stats[:rate_limits] > @stats[:translations] * 0.5
      { status: :warning, message: "Frequent rate limiting" }
    else
      { status: :healthy, message: "All systems operational" }
    end
  end
end

# === CLASSE: Alerting System ===

class AlertingSystem
  def initialize(metrics_collector)
    @metrics = metrics_collector
    @alerts_sent = Set.new
    @alert_cooldown = 300 # 5 minutes
    @last_alerts = {}
  end

  def check_and_alert!
    health = @metrics.health_status

    case health[:status]
    when :critical
      send_alert(:critical, health[:message])
    when :warning
      send_alert(:warning, health[:message])
    end

    # Vérifications spécifiques
    check_rate_limiting!
    check_error_spikes!
    check_performance_degradation!
  end

  private

  def check_rate_limiting!
    return unless @metrics.instance_variable_get(:@stats)[:rate_limits] > 10

    send_alert(:warning, "Excessive rate limiting detected")
  end

  def check_error_spikes!
    return unless @metrics.error_rate > 15

    send_alert(:critical, "Error rate spike: #{@metrics.error_rate}%")
  end

  def check_performance_degradation!
    stats = @metrics.instance_variable_get(:@stats)
    return unless stats[:translations].positive?

    avg_duration = stats[:total_duration] / stats[:translations]
    return unless avg_duration > 10.0 # Plus de 10 secondes en moyenne

    send_alert(:warning, "Performance degradation: #{avg_duration.round(2)}s avg")
  end

  def send_alert(level, message)
    alert_key = "#{level}_#{message}"

    # Cooldown check
    return if @last_alerts[alert_key] && Time.now - @last_alerts[alert_key] < @alert_cooldown

    @last_alerts[alert_key] = Time.now

    # Simuler l'envoi d'alerte
    icon = level == :critical ? "🚨" : "⚠️"
    puts "#{icon} ALERT [#{level.upcase}]: #{message}"

    # Ici vous pourriez intégrer:
    # - Slack notifications
    # - Email alerts
    # - PagerDuty
    # - Sentry
    # - Custom webhooks

    simulate_external_alert(level, message)
  end

  def simulate_external_alert(_level, _message)
    # Exemple d'intégration Slack
    if ENV["SLACK_WEBHOOK_URL"]
      # webhook_payload = {
      #   text: "MistralTranslator Alert",
      #   attachments: [{
      #     color: level == :critical ? "danger" : "warning",
      #     fields: [{
      #       title: level.to_s.capitalize,
      #       value: message,
      #       short: false
      #     }]
      #   }]
      # }
      puts "  → Slack notification sent"
    end

    # Exemple d'intégration Sentry
    return unless ENV["SENTRY_DSN"]

    # Sentry.capture_message(message, level: level)
    puts "  → Sentry event created"
  end
end

# === CLASSE: Dashboard Data Generator ===

class MonitoringDashboard
  def initialize(metrics_collector)
    @metrics = metrics_collector
  end

  def generate_dashboard_data
    stats = @metrics.instance_variable_get(:@stats)

    {
      overview: {
        translations_count: stats[:translations],
        error_count: stats[:errors],
        error_rate: @metrics.error_rate,
        rate_limits: stats[:rate_limits],
        health_status: @metrics.health_status
      },

      performance: {
        avg_duration: stats[:translations].positive? ? (stats[:total_duration] / stats[:translations]).round(3) : 0,
        total_duration: stats[:total_duration].round(3),
        chars_per_second: calculate_chars_per_second(stats),
        text_expansion_ratio: calculate_expansion_ratio(stats)
      },

      usage: {
        language_pairs: stats[:by_language].sort_by { |_, count| -count }.first(10),
        hourly_activity: stats[:hourly_stats].sort_by { |hour, _| hour }.last(24),
        error_breakdown: stats[:error_types]
      },

      system: {
        uptime: (Time.now - @metrics.instance_variable_get(:@start_time)).round(2),
        gem_version: MistralTranslator::VERSION,
        ruby_version: RUBY_VERSION,
        timestamp: Time.now.iso8601
      }
    }
  end

  def export_to_json(filename = "translation_dashboard_#{Time.now.strftime("%Y%m%d_%H%M%S")}.json")
    data = generate_dashboard_data
    File.write(filename, JSON.pretty_generate(data))
    puts "📄 Dashboard data exported to: #{filename}"
    filename
  end

  private

  def calculate_chars_per_second(stats)
    uptime = Time.now - @metrics.instance_variable_get(:@start_time)
    uptime.positive? ? (stats[:total_chars_input] / uptime).round(2) : 0
  end

  def calculate_expansion_ratio(stats)
    return 1.0 if stats[:total_chars_input].zero?

    (stats[:total_chars_output].to_f / stats[:total_chars_input]).round(3)
  end
end

# === UTILISATION ET DÉMONSTRATION ===

puts "\n1. Setting up monitoring..."
metrics = TranslationMetricsCollector.new
alerting = AlertingSystem.new(metrics)
dashboard = MonitoringDashboard.new(metrics)

puts "\n2. Testing with sample translations..."

# Test basique pour vérifier la connexion
begin
  test_result = MistralTranslator.translate("Hello monitoring", from: "en", to: "fr")
  puts "API connection OK: #{test_result}"
rescue MistralTranslator::Error => e
  puts "API Error: #{e.message}"
  puts "Continuing with monitoring setup demo..."
end

# Simuler différents scénarios
sample_texts = [
  "Bonjour le monde",
  "Comment allez-vous ?",
  "Ruby on Rails",
  "Test de monitoring",
  "Système de surveillance"
]

puts "\n3. Running sample translations to generate metrics..."

sample_texts.each_with_index do |text, i|
  MistralTranslator.translate(text, from: "fr", to: "en")
  print "."

  # Simuler quelques erreurs pour les métriques
  if i == 2
    begin
      MistralTranslator.translate("", from: "invalid", to: "fr")
    rescue MistralTranslator::Error
      # Erreur attendue pour les métriques
    end
  end

  sleep(0.2) # Rate limiting
rescue MistralTranslator::Error => e
  print "x"
end

puts "\n\n4. Checking alerts..."
alerting.check_and_alert!

puts "\n5. Generating reports..."
metrics.report

puts "\n6. Health status check..."
health = metrics.health_status
puts "🏥 Health: #{health[:status]} - #{health[:message]}"

puts "\n7. Exporting dashboard data..."
dashboard_file = dashboard.export_to_json

puts "\n8. Built-in metrics from MistralTranslator:"
if MistralTranslator.configuration.enable_metrics
  built_in_metrics = MistralTranslator.metrics
  puts "📊 Built-in metrics:"
  built_in_metrics.each do |key, value|
    puts "   #{key}: #{value}"
  end
else
  puts "⚠️  Built-in metrics not enabled"
end

# === CONFIGURATION POUR PRODUCTION ===

puts "\n#{"=" * 50}"
puts "📋 PRODUCTION MONITORING SETUP EXAMPLE"
puts "=" * 50

puts <<~SETUP
  # config/initializers/mistral_translator.rb
  MistralTranslator.configure do |config|
    config.api_key = ENV['MISTRAL_API_KEY']
    config.enable_metrics = true
  #{"  "}
    # Callbacks pour intégration monitoring
    config.on_translation_error = ->(from, to, error, attempt, timestamp) {
      # Sentry/Honeybadger
      if defined?(Sentry)
        Sentry.capture_exception(error, extra: {
          translation_direction: "\#{from} -> \#{to}",
          attempt_number: attempt
        })
      end
  #{"    "}
      # Logs structurés
      Rails.logger.error({
        event: 'translation_error',
        from_language: from,
        to_language: to,
        error_class: error.class.name,
        error_message: error.message,
        attempt: attempt,
        timestamp: timestamp
      }.to_json)
    }
  #{"  "}
    config.on_rate_limit = ->(from, to, wait_time, attempt, timestamp) {
      # Métriques custom (StatsD, DataDog, etc.)
      if defined?(StatsD)
        StatsD.increment('mistral_translator.rate_limit',
          tags: ["from:\#{from}", "to:\#{to}"])
      end
    }
  #{"  "}
    config.on_translation_complete = ->(from, to, orig, trans, duration) {
      # Métriques de performance
      if defined?(StatsD)
        StatsD.timing('mistral_translator.duration', duration * 1000,
          tags: ["from:\#{from}", "to:\#{to}"])
        StatsD.histogram('mistral_translator.chars_ratio',#{" "}
          trans.to_f / orig, tags: ["from:\#{from}", "to:\#{to}"])
      end
    }
  end
SETUP

puts "\n🎉 Monitoring setup complete!"

# Nettoyage
FileUtils.rm_f(dashboard_file)
