## [Unreleased - 0.5.0]

### Added

- `config.read_timeout`: how long to wait for the API's answer, in seconds. Defaults to 60, the value the gem used until now; anything but a positive number raises `ConfigurationError` when it is set.

## [Unreleased]

Internal cleanup: no change to the documented API or to translation results.

### Changed

- Translations and summaries share one retry policy, with the same delays and counts as before. Their retry log lines now share one format, such as `translation retry 1/3 for fr->en in 2s: …`.
- The `Summarizer` no longer prints to stdout when `MISTRAL_TRANSLATOR_TEST_OUTPUT` is set.
- A response is parsed once instead of twice.

### Security

- When the scan for a JSON object inside text reached its limit, the error kept the `JSON::ParserError` as its `cause`, and that error quotes the response.

### Removed

Undocumented code that the gem never called:

- the `HelpersExtensions` copies of `translate_with_progress`, `translate_multi_style` and `find_locale_suggestions`, which `Helpers` redefines;
- `TranslatorHelpers::RetryHandler`, `TranslatorHelpers::LoggingHelper` and `InputValidator#validate_batch_inputs!`;
- `PromptBuilder.bulk_translation_prompt`, `PromptBuilder.tiered_summary_prompt`, `PromptHelpers::FormatInstructions`, `ResponseParser.parse_bulk_translation_response` and `ResponseParser::JsonParserState`.

## [0.4.0] - 2026-10-28

### Changed

These changes alter behaviour that callers may rely on:

- Unusable responses now raise instead of being returned. A response without JSON, with a target that is not text, or with a blank target raises `InvalidResponseError` or `EmptyTranslationError` after the usual retries. Previously the raw response text could be stored as the translation or the summary.
- `summarize_and_translate` no longer falls back to an untranslated summary in the source language; it retries like the other summaries, then raises.
- `translate_auto` raises `InvalidResponseError` when language detection is unreadable or names an unsupported language. It used to assume English, which returned the source text untranslated when the target was English.
- `PromptBuilder` methods return a `MistralTranslator::Prompt` (`instructions` and `text`) instead of a String. `Prompt#to_s` gives the previous single-text form.
- Prompts are sent as two messages: instructions in the system message, the text alone in the user message, between delimiters, with a rule telling the model to treat it as data.
- `Client#complete` takes `json: false`. The gem's own calls pass `json: true`, which sends `response_format: json_object`.
- 182 languages instead of 13: every ISO 639-1 code named by CLDR. `SUPPORTED_LANGUAGES` keeps the native names, unchanged for the original 13, and `supported_languages` returns a much longer string. Quality depends on the model and is weaker for rare languages.
- In `translate_batch` and the batch path of `translate_to_multiple`, an unreadable response fails its own item (`nil`) instead of the whole batch.
- `translate_auto`, `translate_to_multiple` and the summaries enforce the same 50,000 character limit as `translate`.

### Added

- `config.proxy`: an `http://` proxy URL or URI, or `:env` to read `HTTPS_PROXY`, then `HTTP_PROXY`, honouring `NO_PROXY`. Disabled by default.
- `preserve_html:` in `translate_batch` and `translate_auto`.
- `context:` and `style:` in every summary method.
- English and French language names are accepted in place of codes (`"German"`, `"allemand"`), and locale suggestions are based on language names.
- `bin/generate_languages` regenerates `lib/mistral_translator/data/languages.json` from CLDR (macOS).

### Fixed

- `Helpers.smart_summarize` raised `ArgumentError` on every call.
- A translated text mentioning "rate limit" or "quota exceeded" was taken for a rate limit, retried, then failed. Only the 429 status counts now.
- Context and glossary were formatted three different ways; an empty glossary printed `GLOSSAIRE : {}` in quality check prompts, and the `has_context` / `has_glossary` metadata were never set.
- `translate_batch` silently ignored misspelled options.
- Locale suggestions returned unrelated codes once every ISO 639-1 language was supported.

### Security

- User text and API responses no longer reach logs or error messages: the verbose request log records sizes only, error messages carry no response content, errors no longer keep the original Ruby error as `cause`, and the error callback receives the sanitized error. The response stays available through `InvalidResponseError#raw_response`.
- Delimiters found in the text are neutralised so it cannot close its block, and `Prompt#inspect` shows lengths only.
- `https://` proxies are rejected: net-http-persistent talks to the proxy in clear, so their credentials would travel unencrypted.

### Removed

- `TranslatorHelpers::PromptHandler` and the test-only `make_request` fallback in `perform_client_request`.

## [0.3.2] - 2026-10-28

### Fixed

- Rich text adapters send the stored ActionText HTML (`to_html`) instead of the rendered one (`to_s`), which wrapped every translation in an extra `<div class="trix-content">` and inlined the rendered attachments. `ActionText::Content` values are now recognised too, not only `ActionText::RichText`.
- `RecordTranslationService` passes `preserve_html: true` for rich text fields.
- `RecordTranslationService#translate_to_all_locales` returns `false` when a translation fails. It returned `true`, so failures went unnoticed; successful translations are still saved.
- `RecordTranslationService`, `Translator` and `Summarizer` stop retrying after a few `RateLimitError`s and raise, instead of retrying forever on top of the client's own backoff.
- `translate_to_multiple` passes `preserve_html` to each translation; the option was ignored.
- `translate_with_mistral` raised `ArgumentError` on every call. `from:` is now the source locale and `to:` the target locales, through a new `target_locales:` option of `RecordTranslationService`.
- A glossary given as a string no longer raises `NoMethodError` in `PromptBuilder`.
- `BasicRateLimiter` no longer sleeps while holding its lock, which blocked every other thread.
- HTTP error messages no longer end with a stray brace.

### Changed

- CI token restricted to read access, and development dependencies updated (addressable, json, uri).

### Removed

- Unused helpers `log_prompt_debug` and `build_html_validation_instruction`.

## [0.3.1] - 2026-10-27

### Fixed

- Default model is now `mistral-small-latest`. Mistral retired the `mistral-small` name, so every call without an explicit `config.model` failed with a 404. The alias follows the current Mistral Small version; set `config.model` to pin one.

### Added

- `bin/check_api`: checks the API key and the default model, then runs the examples against the real API when the plan allows generation. The key is read from `MISTRAL_TEST_API_KEY`, `.env`, or a hidden prompt, and never printed.
- Weekly workflow running `bin/check_api`, which opens an issue on failure.

### Changed

- CI: a single workflow, RuboCop plus the test suite on Ruby 3.2, 3.3, 3.4 and 4.0.
- The test suite no longer prints part of the API key, and no longer deletes VCR cassettes after each run.

## [0.3.0] - 2025-12-09

### Added

- Thread-safe metrics with Mutex protection for concurrent usage
- Connection pooling with net-http-persistent (automatic connection reuse)
- SSL/TLS configuration options: `ssl_verify_mode`, `ssl_ca_file`, `ssl_ca_path`, `ssl_timeout`
- Thread-safe logger cache for `warn_once` method
- Comprehensive concurrent/async documentation with SolidQueue, Sidekiq, Concurrent Ruby examples
- 39 new tests for thread-safety, SSL configuration, and connection pooling

### Changed

- HTTP client now uses Net::HTTP::Persistent for better performance
- Configuration metrics now thread-safe across concurrent requests
- Documentation reorganized with SolidQueue as recommended background job backend

### Performance

- Connection pooling reduces TCP handshake overhead
- Thread-safe implementation enables safe concurrent translations
- Configurable SSL timeout for production environments

## [0.2.0] - 2025-09-09

### Added

- Contexte et glossaire via `MistralTranslator::Translator#translate`
- Rate limiting client (50 req/min par défaut, thread-safe)
- Validation basique des entrées (max 50k chars, batch ≤ 20)
- Nouvelles erreurs: `SecurityError`, `RateLimitExceededError`
- Métriques intégrées et callbacks de monitoring
- Documentation mise à jour + guide de migration 0.1.0 → 0.2.0

### Changed

- Exemples et docs: utilisation d’une instance `Translator` pour `context`/`glossary`
- Amélioration de la structure interne (client/translator/summarizer)

### Fixed

- Masquage renforcé des secrets dans VCR
- Messages d’erreurs plus explicites pour les réponses invalides

## [0.1.0] - 2025-09-01

- Initial release
