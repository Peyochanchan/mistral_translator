#!/usr/bin/env ruby
# frozen_string_literal: true

# Exemple d'utilisation de base de la gem MistralTranslator
require "mistral_translator"

# Configuration
MistralTranslator.configure do |config|
  config.api_key = ENV["MISTRAL_API_KEY"] || "your_api_key_here"
  # config.api_url = 'https://api.mistral.ai'  # optionnel
  # config.model = 'mistral-small'             # optionnel
end

puts "=== MistralTranslator Examples ==="
puts "Version: #{MistralTranslator.version}"
puts

# Vérification de la santé de l'API
puts "🔍 Health Check:"
health = MistralTranslator.health_check
puts "Status: #{health[:status]} - #{health[:message]}"
puts

# Exemple 1: Traduction simple
puts "📝 Traduction simple:"
begin
  result = MistralTranslator.translate("Bonjour le monde", from: "fr", to: "en")
  puts "FR → EN: 'Bonjour le monde' → '#{result}'"
rescue MistralTranslator::Error => e
  puts "Erreur: #{e.message}"
end
puts

# Exemple 2: Traduction vers plusieurs langues
puts "🌍 Traduction vers plusieurs langues:"
begin
  results = MistralTranslator.translate_to_multiple(
    "Hello world",
    from: "en",
    to: %w[fr es de]
  )

  results.each do |locale, translation|
    puts "EN → #{locale.upcase}: '#{translation}'"
  end
rescue MistralTranslator::Error => e
  puts "Erreur: #{e.message}"
end
puts

# Exemple 3: Traduction en lot
puts "📦 Traduction en lot:"
begin
  texts = ["Good morning", "Good afternoon", "Good evening"]
  results = MistralTranslator.translate_batch(texts, from: "en", to: "fr")

  results.each do |index, translation|
    puts "#{index}: '#{texts[index]}' → '#{translation}'"
  end
rescue MistralTranslator::Error => e
  puts "Erreur: #{e.message}"
end
puts

# Exemple 4: Auto-détection de langue
puts "🔍 Auto-détection de langue:"
begin
  result = MistralTranslator.translate_auto("¡Hola mundo!", to: "en")
  puts "Auto-détection → EN: '#{result}'"
rescue MistralTranslator::Error => e
  puts "Erreur: #{e.message}"
end
puts

# Exemple 5: Résumé de texte
puts "📄 Résumé de texte:"
long_text = <<~TEXT
  Ruby on Rails est un framework de développement web écrit en Ruby qui suit le paradigme#{" "}
  Modèle-Vue-Contrôleur (MVC). Il privilégie la convention plutôt que la configuration,#{" "}
  ce qui permet aux développeurs de créer rapidement des applications web robustes.#{" "}
  Rails comprend de nombreux outils intégrés comme Active Record pour l'ORM,#{" "}
  Action View pour les templates, Action Controller pour la logique métier,#{" "}
  et bien d'autres composants. Le framework a été créé par David Heinemeier Hansson#{" "}
  en 2004 et continue d'évoluer avec une communauté active de développeurs.
TEXT

begin
  summary = MistralTranslator.summarize(long_text, language: "fr", max_words: 50)
  puts "Texte original: #{long_text.length} caractères"
  puts "Résumé (50 mots max): #{summary}"
rescue MistralTranslator::Error => e
  puts "Erreur: #{e.message}"
end
puts

# Exemple 6: Résumé avec traduction
puts "🔄 Résumé + Traduction:"
begin
  result = MistralTranslator.summarize_and_translate(
    long_text,
    from: "fr",
    to: "en",
    max_words: 75
  )
  puts "Résumé traduit EN (75 mots max): #{result}"
rescue MistralTranslator::Error => e
  puts "Erreur: #{e.message}"
end
puts

# Exemple 7: Résumés par niveaux
puts "📊 Résumés par niveaux:"
begin
  tiered = MistralTranslator.summarize_tiered(
    long_text,
    language: "fr",
    short: 25,
    medium: 75,
    long: 150
  )

  puts "Court (25 mots): #{tiered[:short]}"
  puts "Moyen (75 mots): #{tiered[:medium]}"
  puts "Long (150 mots): #{tiered[:long]}"
rescue MistralTranslator::Error => e
  puts "Erreur: #{e.message}"
end
puts

# Informations sur les langues supportées
puts "🌐 Langues supportées:"
puts MistralTranslator.supported_languages
puts

puts "✅ Exemples terminés!"
