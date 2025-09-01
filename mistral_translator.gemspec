# frozen_string_literal: true

require_relative "lib/mistral_translator/version"

Gem::Specification.new do |spec|
  spec.name = "mistral_translator"
  spec.version = MistralTranslator::VERSION
  spec.authors = ["Peyochanchan"]
  spec.email = ["cameleon24@outlook.fr"]

  spec.summary = "Gem to translate and summarize text with Mistral API"
  spec.description = "Allows translating text into different languages and generating summaries using the MistralAI API"

  spec.homepage = "https://github.com/Peyochanchan/mistral_translator"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "https://github.com/Peyochanchan/mistral_translator"
  spec.metadata["changelog_uri"] = "https://github.com/Peyochanchan/mistral_translator/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile]) ||
        f.match?(/\.gem$/)
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "net-http", "~> 0.4"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.21"
  spec.add_development_dependency "vcr", "~> 6.2"
  spec.add_development_dependency "webmock", "~> 3.18"
end
