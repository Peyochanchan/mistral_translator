# Contributing to MistralTranslator

Thank you for your interest in contributing to MistralTranslator! We welcome contributions of all kinds.

## Development Setup

### Prerequisites

- Ruby 3.2+
- Bundler

### Installation

```bash
git clone https://github.com/your-username/mistral_translator.git
cd mistral_translator
bundle install
```

## Running Tests

```bash
# Unit tests (no API key required)
bundle exec rspec

# Integration tests (requires real API key)
export MISTRAL_API_KEY=your_key && bundle exec rspec spec/integration/mistral_api_integration_spec.rb

# All tests with coverage
bundle exec rspec --format documentation
```

## Contributing Guidelines

### Reporting Issues

- Use GitHub Issues for bug reports and feature requests
- Include Ruby version, gem version, and relevant code snippets
- For API-related issues, include sanitized request/response examples

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes with tests
4. Ensure all tests pass: `bundle exec rspec`
5. Follow Ruby style conventions (we use RuboCop - no error) : `bundle exec rubocop`
6. Submit a pull request with a clear description

### Code Standards

- Write tests for new features and bug fixes
- Follow existing code patterns and architecture
- Update documentation for public API changes
- Keep commits atomic and well-described

### Testing

- Unit tests should not require API calls (use mocks/stubs)
- Integration tests should use VCR cassettes when possible
- Test edge cases and error conditions
- Test coverage must be at 100% (for now)

## Release Process

Releases are handled by maintainers following semantic versioning.

## Questions?

Feel free to open an issue for any questions about contributing.
