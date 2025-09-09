#!/usr/bin/env ruby
# frozen_string_literal: true

# Exemple de traitement par batch avec MistralTranslator
# Usage: ruby examples/batch-job.rb

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "mistral_translator"

# Configuration
MistralTranslator.configure do |config|
  config.api_key = ENV["MISTRAL_API_KEY"] || "your_api_key_here"
  config.enable_metrics = true
  config.retry_delays = [2, 4, 8, 16]
end

# === EXEMPLE 1: Traduction de fichiers CSV ===

require "csv"

class CSVTranslationBatch
  def initialize(input_file, output_file, from:, to:, text_columns: [])
    @input_file = input_file
    @output_file = output_file
    @from = from
    @to = to
    @text_columns = text_columns
    @batch_size = 10
  end

  def process!
    rows = CSV.read(@input_file, headers: true)
    puts "📄 Processing #{rows.size} rows from #{@input_file}"

    translated_rows = []

    rows.each_slice(@batch_size) do |batch|
      puts "🔄 Processing batch of #{batch.size} rows..."
      translated_batch = process_batch(batch)
      translated_rows.concat(translated_batch)

      # Rate limiting
      sleep(2) unless batch == rows.last(@batch_size)
    end

    # Écriture du fichier de sortie
    CSV.open(@output_file, "w", headers: true) do |csv|
      # Headers
      csv << translated_rows.first.headers if translated_rows.any?

      # Data
      translated_rows.each { |row| csv << row }
    end

    puts "✅ Traduction terminée: #{@output_file}"
  end

  private

  def process_batch(batch)
    batch.map do |row|
      translated_row = row.dup

      @text_columns.each do |column|
        text = row[column]
        next if text.nil? || text.empty?

        begin
          translated = MistralTranslator.translate(text, from: @from, to: @to)
          translated_row["#{column}_#{@to}"] = translated
        rescue MistralTranslator::Error => e
          puts "❌ Error translating row #{row.to_h}: #{e.message}"
          translated_row["#{column}_#{@to}"] = "[TRANSLATION_ERROR]"
        end
      end

      translated_row
    end
  end
end

# === EXEMPLE 2: Job de traduction avec queue ===

class TranslationQueue
  def initialize
    @queue = []
    @results = {}
    @workers = 3
    @batch_size = 5
  end

  def add_job(id, text, from:, to:, context: nil)
    @queue << {
      id: id,
      text: text,
      from: from,
      to: to,
      context: context,
      status: :pending
    }
  end

  def process_all!
    puts "🚀 Starting translation queue with #{@workers} workers"
    puts "📋 #{@queue.size} jobs to process"

    threads = []
    job_chunks = @queue.each_slice(@batch_size).to_a

    @workers.times do |worker_id|
      threads << Thread.new do
        process_worker_jobs(worker_id, job_chunks)
      end
    end

    threads.each(&:join)

    # Résultats
    successful = @results.values.count { |r| r[:status] == :success }
    failed = @results.values.count { |r| r[:status] == :error }

    puts "\n📊 Results:"
    puts "✅ Successful: #{successful}"
    puts "❌ Failed: #{failed}"
    puts "📈 Success rate: #{(successful.to_f / @queue.size * 100).round(1)}%"

    @results
  end

  private

  def process_worker_jobs(worker_id, job_chunks)
    my_chunks = job_chunks.select.with_index { |_, i| i % @workers == worker_id }

    my_chunks.each do |chunk|
      puts "🔧 Worker #{worker_id} processing #{chunk.size} jobs"

      chunk.each do |job|
        process_single_job(worker_id, job)
      end

      # Rate limiting entre les chunks
      sleep(1)
    end
  end

  def process_single_job(worker_id, job)
    translated = MistralTranslator.translate(
      job[:text],
      from: job[:from],
      to: job[:to],
      context: job[:context]
    )

    @results[job[:id]] = {
      status: :success,
      original: job[:text],
      translated: translated,
      worker: worker_id
    }

    puts "✅ Worker #{worker_id}: Job #{job[:id]} completed"
  rescue MistralTranslator::Error => e
    @results[job[:id]] = {
      status: :error,
      original: job[:text],
      error: e.message,
      worker: worker_id
    }

    puts "❌ Worker #{worker_id}: Job #{job[:id]} failed - #{e.message}"
  end
end

# === EXEMPLE 3: Traitement de fichiers JSON ===

require "json"

class JSONBatchProcessor
  def initialize(input_file, output_file)
    @input_file = input_file
    @output_file = output_file
  end

  def translate_nested_json(from:, to:)
    data = JSON.parse(File.read(@input_file))
    puts "📄 Processing JSON file: #{@input_file}"

    translated_data = translate_recursive(data, from, to)

    File.write(@output_file, JSON.pretty_generate(translated_data))
    puts "✅ Translated JSON saved: #{@output_file}"

    translated_data
  end

  private

  def translate_recursive(obj, from, to, path = [])
    case obj
    when Hash
      result = {}
      obj.each do |key, value|
        current_path = path + [key]

        if translatable_key?(key) && value.is_a?(String)
          puts "🔄 Translating #{current_path.join(".")}: #{value[0..50]}..."

          begin
            result[key] = MistralTranslator.translate(value, from: from, to: to)
            result["#{key}_original"] = value # Garder l'original
          rescue MistralTranslator::Error => e
            puts "❌ Translation failed for #{current_path.join(".")}: #{e.message}"
            result[key] = value # Garder l'original en cas d'erreur
          end
        else
          result[key] = translate_recursive(value, from, to, current_path)
        end
      end
      result

    when Array
      obj.map.with_index do |item, index|
        translate_recursive(item, from, to, path + [index])
      end

    else
      obj # Primitive values
    end
  end

  def translatable_key?(key)
    # Keys qui contiennent du texte à traduire
    %w[title description content text message label name summary].include?(key.to_s.downcase)
  end
end

# === EXEMPLE 4: Batch avec retry et monitoring ===

class RobustBatchProcessor
  def initialize(items, from:, to:)
    @items = items
    @from = from
    @to = to
    @results = {}
    @errors = {}
    @retry_queue = []
  end

  def process_with_monitoring!
    puts "🚀 Starting robust batch processing"
    puts "📊 Items: #{@items.size}"

    # Première passe
    process_initial_batch

    # Retry des éléments échoués
    retry_failed_items if @retry_queue.any?

    # Rapport final
    generate_report

    @results
  end

  private

  def process_initial_batch
    @items.each_with_index do |item, index|
      print_progress(index + 1, @items.size)

      begin
        result = MistralTranslator.translate(item, from: @from, to: @to)
        @results[index] = result
      rescue MistralTranslator::RateLimitError => e
        puts "\n⏳ Rate limit hit, waiting..."
        sleep(30)
        @retry_queue << { index: index, item: item, attempts: 1 }
      rescue MistralTranslator::Error => e
        @errors[index] = e.message
        @retry_queue << { index: index, item: item, attempts: 1 }
      end

      # Rate limiting
      sleep(0.5)
    end

    puts "\n✅ Initial batch completed"
  end

  def retry_failed_items
    puts "🔄 Retrying #{@retry_queue.size} failed items..."

    @retry_queue.each do |retry_item|
      next if retry_item[:attempts] >= 3

      begin
        result = MistralTranslator.translate(retry_item[:item], from: @from, to: @to)
        @results[retry_item[:index]] = result
        puts "✅ Retry successful for item #{retry_item[:index]}"
      rescue MistralTranslator::Error => e
        retry_item[:attempts] += 1
        @errors[retry_item[:index]] = "#{e.message} (#{retry_item[:attempts]} attempts)"
        puts "❌ Retry failed for item #{retry_item[:index]}: #{e.message}"
      end

      sleep(2) # Plus de délai pour les retries
    end
  end

  def print_progress(current, total)
    percentage = (current.to_f / total * 100).round(1)
    print "\r🔄 Progress: #{current}/#{total} (#{percentage}%)"
  end

  def generate_report
    successful = @results.size
    failed = @errors.size
    total = @items.size

    puts "\n\n📊 BATCH PROCESSING REPORT"
    puts "=" * 40
    puts "Total items: #{total}"
    puts "Successful: #{successful} (#{(successful.to_f / total * 100).round(1)}%)"
    puts "Failed: #{failed} (#{(failed.to_f / total * 100).round(1)}%)"

    # Métriques MistralTranslator
    if MistralTranslator.configuration.enable_metrics
      metrics = MistralTranslator.metrics
      puts "\n📈 Translation Metrics:"
      puts "Total translations: #{metrics[:total_translations]}"
      puts "Average time: #{metrics[:average_translation_time]}s"
      puts "Error rate: #{metrics[:error_rate]}%"
    end

    # Top errors
    return unless @errors.any?

    puts "\n❌ Top Errors:"
    error_groups = @errors.values.group_by(&:itself)
    error_groups.sort_by { |_, v| -v.size }.first(3).each do |error, occurrences|
      puts "  #{error}: #{occurrences.size} times"
    end
  end
end

# === UTILISATION ===

puts "=== MistralTranslator Batch Processing Examples ==="

# Test de base avec vérification de l'API
begin
  test_result = MistralTranslator.translate("Hello", from: "en", to: "fr")
  puts "✅ API connection OK: #{test_result}"
rescue MistralTranslator::Error => e
  puts "❌ API Error: #{e.message}"
  puts "Continuing with examples that don't require API..."
end

# EXEMPLE 1: CSV
puts "\n1. CSV Translation Example"
puts "-" * 30

# Créer un fichier CSV d'exemple
sample_csv = "tmp_products.csv"
CSV.open(sample_csv, "w", headers: true) do |csv|
  csv << %w[id name description]
  csv << ["1", "Laptop Premium", "Ordinateur portable haute performance"]
  csv << ["2", "Souris Gaming", "Souris optique pour gaming"]
  csv << ["3", "Clavier Mécanique", "Clavier mécanique rétroéclairé"]
end

if File.exist?(sample_csv)
  processor = CSVTranslationBatch.new(
    sample_csv,
    "tmp_products_en.csv",
    from: "fr",
    to: "en",
    text_columns: %w[name description]
  )

  begin
    processor.process!
  rescue StandardError => e
    puts "CSV processing error: #{e.message}"
  ensure
    File.delete(sample_csv) if File.exist?(sample_csv)
    File.delete("tmp_products_en.csv") if File.exist?("tmp_products_en.csv")
  end
end

# EXEMPLE 2: Queue
puts "\n2. Translation Queue Example"
puts "-" * 30

queue = TranslationQueue.new

# Ajouter des jobs
sample_texts = [
  "Bonjour le monde",
  "Comment allez-vous ?",
  "Ruby on Rails est génial",
  "J'aime la programmation",
  "Les tests sont importants"
]

sample_texts.each_with_index do |text, i|
  queue.add_job(i, text, from: "fr", to: "en", context: "casual conversation")
end

begin
  results = queue.process_all!

  puts "\nSample results:"
  results.values.first(2).each do |result|
    if result[:status] == :success
      puts "  #{result[:original]} → #{result[:translated]}"
    else
      puts "  ERROR: #{result[:error]}"
    end
  end
rescue StandardError => e
  puts "Queue processing error: #{e.message}"
end

# EXEMPLE 3: JSON
puts "\n3. JSON Translation Example"
puts "-" * 30

sample_json = {
  "app" => {
    "title" => "Mon Application",
    "description" => "Une application formidable pour tous",
    "version" => "1.0.0",
    "features" => [
      {
        "name" => "Traduction Automatique",
        "description" => "Traduit votre contenu instantanément"
      },
      {
        "name" => "Interface Intuitive",
        "description" => "Design simple et élégant"
      }
    ]
  }
}

json_file = "tmp_app.json"
File.write(json_file, JSON.generate(sample_json))

processor = JSONBatchProcessor.new(json_file, "tmp_app_en.json")

begin
  processor.translate_nested_json(from: "fr", to: "en")
rescue StandardError => e
  puts "JSON processing error: #{e.message}"
ensure
  File.delete(json_file) if File.exist?(json_file)
  File.delete("tmp_app_en.json") if File.exist?("tmp_app_en.json")
end

# EXEMPLE 4: Robust batch
puts "\n4. Robust Batch Processing Example"
puts "-" * 30

texts_to_translate = [
  "Bienvenue dans notre application",
  "Votre compte a été créé avec succès",
  "Merci pour votre commande",
  "Erreur de connexion au serveur",
  "Votre mot de passe a été mis à jour"
]

robust_processor = RobustBatchProcessor.new(
  texts_to_translate,
  from: "fr",
  to: "en"
)

begin
  results = robust_processor.process_with_monitoring!
rescue StandardError => e
  puts "Robust batch error: #{e.message}"
end

puts "\n🎉 All batch examples completed!"
