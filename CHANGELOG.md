## [Unreleased]

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
