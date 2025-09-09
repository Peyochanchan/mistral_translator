#!/usr/bin/env ruby
# frozen_string_literal: true

# Exemple d'usage de base de MistralTranslator
# Usage: ruby examples/basic_usage.rb

# Préférer la version locale de la gem (pour tester la version du repo)
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "mistral_translator"

# Configuration minimale
MistralTranslator.configure do |config|
  config.api_key = ENV["MISTRAL_API_KEY"] || "your_api_key_here"
end

puts "=== MistralTranslator Examples ==="
puts

# Vérification de base
begin
  # Test simple pour vérifier que l'API fonctionne
  test = MistralTranslator.translate("Hello", from: "en", to: "fr")
  puts "Configuration OK - Test: #{test}"
rescue MistralTranslator::AuthenticationError
  puts "ERREUR: Clé API invalide. Définissez MISTRAL_API_KEY"
  exit 1
rescue MistralTranslator::ConfigurationError
  puts "ERREUR: Configuration manquante"
  exit 1
rescue StandardError => e
  puts "ERREUR: #{e.message}"
  exit 1
end
puts

# 1. Traduction de base
puts "1. Traduction simple"
puts "-" * 20
result = MistralTranslator.translate("Bonjour le monde", from: "fr", to: "en")
puts "FR → EN: #{result}"
puts

translator = MistralTranslator::Translator.new

# Détection de la prise en charge de `context` et `glossary` (>= 0.2.0)
supports_context_glossary = Gem::Version.new(MistralTranslator::VERSION) >= Gem::Version.new("0.2.0")

# 2. Traduction avec contexte
puts "2. Traduction avec contexte"
puts "-" * 27
result = if supports_context_glossary
           translator.translate(
             "Batterie faible",
             from: "fr",
             to: "en",
             context: "Smartphone notification"
           )
         else
           translator.translate(
             "Batterie faible",
             from: "fr",
             to: "en"
           )
         end
puts "Avec contexte: #{result}"
puts

# 3. Traduction avec glossaire
puts "3. Traduction avec glossaire"
puts "-" * 28
result = if supports_context_glossary
           translator.translate(
             "L'IA révolutionne le secteur",
             from: "fr",
             to: "en",
             glossary: { "IA" => "AI" }
           )
         else
           translator.translate(
             "L'IA révolutionne le secteur",
             from: "fr",
             to: "en"
           )
         end
puts "Avec glossaire: #{result}"
puts

# 4. Auto-détection
puts "4. Auto-détection de langue"
puts "-" * 27
texts = ["¡Hola mundo!", "Guten Tag", "Ciao mondo"]
texts.each do |text|
  result = MistralTranslator.translate_auto(text, to: "fr")
  puts "#{text} → #{result}"
end
puts

# 5. Traduction vers plusieurs langues
puts "5. Multi-langues"
puts "-" * 14
results = translator.translate_to_multiple(
  "Bienvenue",
  from: "fr",
  to: %w[en es de]
)
results.each { |lang, text| puts "#{lang.upcase}: #{text}" }
puts

# 6. Traduction par lot
puts "6. Traduction par lot"
puts "-" * 19
texts = ["Bonjour", "Merci", "Au revoir"]
results = MistralTranslator.translate_batch(texts, from: "fr", to: "en")
results.each { |i, translation| puts "#{texts[i]} → #{translation}" }
puts

# 7. Résumé simple
puts "7. Résumé de texte"
puts "-" * 17
article = "Ruby on Rails est un framework web MVC écrit en Ruby qui privilégie la convention sur la configuration. Il inclut Active Record pour l'ORM, Action View pour les vues, et Action Controller pour la logique métier."

summary = MistralTranslator.summarize(article, language: "fr", max_words: 25)
puts "Résumé: #{summary}"
puts

# 8. Résumé avec traduction
puts "8. Résumé + traduction"
puts "-" * 22
result = MistralTranslator.summarize_and_translate(
  article,
  from: "fr",
  to: "en",
  max_words: 30
)
puts "EN: #{result}"
puts

# 9. Résumés multi-niveaux
puts "9. Résumés par niveaux"
puts "-" * 22
tiered = MistralTranslator.summarize_tiered(
  article,
  language: "fr",
  short: 15,
  medium: 30,
  long: 50
)
puts "Court: #{tiered[:short]}"
puts "Moyen: #{tiered[:medium]}"
puts

# 10. Informations sur la gem
puts "10. Informations"
puts "-" * 15
puts "Langues: #{MistralTranslator.supported_locales.join(", ")}"
puts

puts "Tous les exemples terminés !"
