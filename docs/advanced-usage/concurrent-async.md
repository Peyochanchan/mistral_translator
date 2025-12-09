# Concurrent & Asynchronous Processing

MistralTranslator is thread-safe and optimized for concurrent usage with protected metrics, connection pooling, and built-in rate limiting.

## Thread Safety

**Protected components:**
- Metrics tracking with Mutex
- Logger cache with concurrent access control
- Rate limiter with thread synchronization
- HTTP connection pooling (Net::HTTP::Persistent)

## Ruby Threads

### Basic Usage

```ruby
languages = ['fr', 'es', 'de', 'it']
threads = languages.map do |lang|
  Thread.new do
    MistralTranslator.translate("Hello", from: 'en', to: lang)
  rescue MistralTranslator::Error => e
    { error: e.message }
  end
end

results = threads.map(&:value)
```

### Thread Pool Pattern

```ruby
# Safe: Limited threads
texts.each_slice(5) do |batch|
  threads = batch.map { |t| Thread.new { translate(t) } }
  threads.each(&:join)
end

# Dangerous: Unlimited threads can exhaust memory
texts.map { |t| Thread.new { translate(t) } }  # Avoid this
```

## Concurrent Ruby (Recommended)

### Installation

```ruby
# Gemfile
gem 'concurrent-ruby', '~> 1.2'
```

### Fixed Thread Pool

```ruby
require 'concurrent'

pool = Concurrent::FixedThreadPool.new(5)

futures = languages.map do |lang|
  Concurrent::Future.execute(executor: pool) do
    MistralTranslator.translate(text, from: 'en', to: lang)
  end
end

results = futures.map(&:value)

pool.shutdown
pool.wait_for_termination
```

### Promise Chains

```ruby
promise = Concurrent::Promise.execute do
  MistralTranslator.translate_auto(text, to: 'en')
end.then do |english|
  target_langs.map do |lang|
    MistralTranslator.translate(english, from: 'en', to: lang)
  end
end.rescue do |error|
  Rails.logger.error "Pipeline failed: #{error}"
  []
end

results = promise.value
```

## Background Jobs

### SolidQueue (Rails 8+, Recommended)

SolidQueue is the default ActiveJob backend in Rails 8, database-backed and Redis-free.

```ruby
# config/database.yml - SolidQueue uses your existing database
production:
  primary:
    <<: *default
  queue:  # Separate DB for jobs (optional)
    <<: *default
    database: app_queue
    migrations_paths: db/queue_migrate

# app/jobs/translation_job.rb
class TranslationJob < ApplicationJob
  queue_as :translations

  retry_on MistralTranslator::RateLimitError, wait: :polynomially_longer
  retry_on MistralTranslator::ApiError, wait: 5.seconds, attempts: 3

  def perform(text, from_locale, to_locale)
    MistralTranslator.translate(text, from: from_locale, to: to_locale)
  end
end

# Usage
languages.each { |lang| TranslationJob.perform_later(text, 'en', lang) }
```

**Configuration:**
```ruby
# config/recurring.yml - Schedule periodic translations
production:
  sync_translations:
    class: TranslationSyncJob
    schedule: every day at 3am
    queue: translations
```

### Sidekiq / Other Backends

Compatible with any ActiveJob backend:

```ruby
class TranslationJob < ApplicationJob
  queue_as :translations
  retry_on MistralTranslator::RateLimitError, wait: :exponentially_longer

  def perform(text, from, to)
    MistralTranslator.translate(text, from: from, to: to)
  end
end
```

## Performance Best Practices

### Configuration for Concurrent Use

```ruby
MistralTranslator.configure do |config|
  config.enable_metrics = true
  config.retry_delays = [1, 2, 4, 8]  # Shorter for concurrent use

  config.on_rate_limit = ->(from, to, wait, attempt, ts) {
    Rails.logger.warn "Rate limit: #{wait}s wait"
  }
end
```

### Recommendations

**Do:**
- Use fixed thread pools (5-10 threads)
- Enable metrics for monitoring
- Use background jobs for non-critical tasks
- Batch similar requests

**Avoid:**
- Unlimited thread creation
- Blocking user requests with translations
- Sharing API keys across environments

## Rate Limiting

The built-in rate limiter (50 requests/60s) is thread-safe but per-process.

**Multiple processes:** Each has its own limiter. With 4 Puma workers = 200 requests/min total.

### Custom Rate Limiter

```ruby
class RedisRateLimiter
  def wait_and_record!
    key = "mistral:#{Time.now.to_i / 60}"
    count = REDIS.incr(key)
    REDIS.expire(key, 60) if count == 1

    sleep(60 - Time.now.to_i % 60) if count > 50
  end
end

client = MistralTranslator::Client.new(
  rate_limiter: RedisRateLimiter.new
)
```

## Monitoring

```ruby
MistralTranslator.configure do |config|
  config.enable_metrics = true

  config.on_translation_complete = ->(from, to, orig, trans, duration) {
    Rails.logger.info "[#{Thread.current.object_id}] #{from}→#{to}: #{duration.round(2)}s"
  }
end

# Thread-safe metrics
metrics = MistralTranslator.metrics
puts "Total: #{metrics[:total_translations]}"
puts "Avg time: #{metrics[:average_translation_time]}s"
puts "Error rate: #{metrics[:error_rate]}%"
```

## Example: High-Performance Service

```ruby
class TranslationService
  def initialize(max_threads: 5)
    @pool = Concurrent::FixedThreadPool.new(max_threads)
  end

  def translate_all(texts, from:, to_languages:)
    futures = texts.flat_map do |text|
      to_languages.map do |lang|
        Concurrent::Future.execute(executor: @pool) do
          MistralTranslator.translate(text, from: from, to: lang)
        end
      end
    end
    futures.map(&:value)
  ensure
    @pool.shutdown
    @pool.wait_for_termination(30)
  end
end
```

## Troubleshooting

**"Too many open files"**
```bash
ulimit -n 4096
```

**Rate limits despite low volume**
Check if multiple processes share the API key. Consider Redis-based rate limiting.

**Memory growth**
```ruby
# Join threads periodically
threads = []
texts.each do |text|
  threads << Thread.new { translate(text) }

  if threads.size >= 10
    threads.each(&:join)
    threads.clear
  end
end
```

## Summary

- Thread-safe with protected metrics and configuration
- Connection pooling automatic with net-http-persistent
- Use fixed-size thread pools (5-10 recommended)
- Built-in rate limiting works across threads
- Background jobs recommended for non-critical tasks
- Separate API keys per environment
