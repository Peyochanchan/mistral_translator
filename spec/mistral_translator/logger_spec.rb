# frozen_string_literal: true

RSpec.describe MistralTranslator::Logger do
  after do
    # Clean up warn cache after each test
    described_class.instance_variable_set(:@warn_cache, nil)
  end

  describe ".info" do
    it "logs info messages" do
      expect { described_class.info("test message") }.not_to raise_error
    end

    it "sanitizes sensitive info messages" do
      allow(described_class).to receive(:log)
      described_class.info("Bearer secret_token_123", sensitive: true)

      expect(described_class).to have_received(:log)
        .with(:info, "Bearer secret_token_123", true)
    end
  end

  describe ".warn" do
    it "logs warning messages" do
      expect { described_class.warn("warning message") }.not_to raise_error
    end
  end

  describe ".debug" do
    it "logs debug messages" do
      # Stub Rails logger if it exists
      if defined?(Rails)
        allow(Rails.logger).to receive(:debug) if Rails.respond_to?(:logger)
      end

      expect { described_class.debug("debug message") }.not_to raise_error
    end
  end

  describe ".warn_once" do
    it "logs a warning the first time" do
      allow(described_class).to receive(:log)

      described_class.warn_once("First warning")

      expect(described_class).to have_received(:log).once
    end

    it "does not log the same warning twice within TTL" do
      allow(described_class).to receive(:log)

      described_class.warn_once("Same warning", ttl: 10)
      described_class.warn_once("Same warning", ttl: 10)

      expect(described_class).to have_received(:log).once
    end

    it "logs again after TTL expires" do
      allow(described_class).to receive(:log)

      described_class.warn_once("Expiring warning", ttl: 0.1)
      sleep(0.2)
      described_class.warn_once("Expiring warning", ttl: 0.1)

      expect(described_class).to have_received(:log).twice
    end

    it "uses custom key for deduplication" do
      allow(described_class).to receive(:log)

      described_class.warn_once("Message 1", key: "same_key", ttl: 10)
      described_class.warn_once("Message 2", key: "same_key", ttl: 10)

      expect(described_class).to have_received(:log).once
    end

    it "handles concurrent calls safely" do
      allow(described_class).to receive(:log)

      threads = 10.times.map do
        Thread.new do
          5.times { described_class.warn_once("concurrent warning", ttl: 10) }
        end
      end

      threads.each(&:join)

      # Should only log once despite 50 concurrent calls
      expect(described_class).to have_received(:log).once
    end
  end

  describe ".debug_if_verbose" do
    context "when MISTRAL_TRANSLATOR_VERBOSE is true" do
      around do |example|
        original_value = ENV["MISTRAL_TRANSLATOR_VERBOSE"]
        ENV["MISTRAL_TRANSLATOR_VERBOSE"] = "true"
        example.run
        ENV["MISTRAL_TRANSLATOR_VERBOSE"] = original_value
      end

      it "logs debug messages" do
        allow(described_class).to receive(:log)
        described_class.debug_if_verbose("verbose message")

        expect(described_class).to have_received(:log).with(:debug, "verbose message", false)
      end
    end

    context "when MISTRAL_TRANSLATOR_VERBOSE is not set" do
      around do |example|
        original_value = ENV["MISTRAL_TRANSLATOR_VERBOSE"]
        ENV["MISTRAL_TRANSLATOR_VERBOSE"] = nil
        example.run
        ENV["MISTRAL_TRANSLATOR_VERBOSE"] = original_value
      end

      it "does not log debug messages" do
        allow(described_class).to receive(:log)
        described_class.debug_if_verbose("verbose message")

        expect(described_class).not_to have_received(:log)
      end
    end
  end

  describe "sanitization" do
    it "masks Bearer tokens" do
      message = "Authorization: Bearer secret_api_key_123"
      sanitized = described_class.send(:sanitize_log_data, message)

      expect(sanitized).to eq("Authorization: Bearer [REDACTED]")
      expect(sanitized).not_to include("secret_api_key_123")
    end

    it "masks API keys in URLs" do
      message = "https://api.example.com?api_key=secret123"
      sanitized = described_class.send(:sanitize_log_data, message)

      expect(sanitized).to include("?api_key=[REDACTED]")
      expect(sanitized).not_to include("secret123")
    end

    it "masks tokens" do
      message = "token=secret_token_456"
      sanitized = described_class.send(:sanitize_log_data, message)

      expect(sanitized).to eq("token=[REDACTED]")
      expect(sanitized).not_to include("secret_token_456")
    end

    it "masks passwords" do
      message = "password=my_secret_password"
      sanitized = described_class.send(:sanitize_log_data, message)

      expect(sanitized).to eq("password=[REDACTED]")
      expect(sanitized).not_to include("my_secret_password")
    end

    it "masks secrets" do
      message = "secret=my_secret_value"
      sanitized = described_class.send(:sanitize_log_data, message)

      expect(sanitized).to eq("secret=[REDACTED]")
      expect(sanitized).not_to include("my_secret_value")
    end

    it "returns non-string data unchanged" do
      expect(described_class.send(:sanitize_log_data, nil)).to be_nil
      expect(described_class.send(:sanitize_log_data, 123)).to eq(123)
      expect(described_class.send(:sanitize_log_data, [])).to eq([])
    end
  end

  describe "thread-safety" do
    it "handles concurrent warn_once calls safely" do
      call_count = 0
      allow(described_class).to receive(:log) { call_count += 1 }

      threads = 20.times.map do
        Thread.new do
          10.times do
            described_class.warn_once("thread-safe warning", ttl: 10)
          end
        end
      end

      threads.each(&:join)

      # Should only log once despite 200 concurrent attempts
      expect(call_count).to eq(1)
    end

    it "maintains separate cache entries for different messages" do
      allow(described_class).to receive(:log)

      threads = 5.times.map do |i|
        Thread.new do
          described_class.warn_once("Warning #{i}", ttl: 10)
        end
      end

      threads.each(&:join)

      # Should log once for each unique message
      expect(described_class).to have_received(:log).exactly(5).times
    end
  end

  describe ".cache_mutex" do
    it "returns a Mutex instance" do
      mutex = described_class.send(:cache_mutex)
      expect(mutex).to be_a(Mutex)
    end

    it "returns the same mutex on multiple calls" do
      mutex1 = described_class.send(:cache_mutex)
      mutex2 = described_class.send(:cache_mutex)
      expect(mutex1).to be(mutex2)
    end
  end
end
