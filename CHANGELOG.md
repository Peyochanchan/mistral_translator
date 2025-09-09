## [Unreleased]

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
