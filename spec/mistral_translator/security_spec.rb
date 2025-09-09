# frozen_string_literal: true

require "spec_helper"

RSpec.describe MistralTranslator::Security::BasicValidator do
  describe ".validate_text!" do
    context "with valid text" do
      it "accepts normal text" do
        expect(described_class.validate_text!("Hello world")).to eq("Hello world")
      end

      it "accepts text with special characters" do
        text = "Café, naïve, résumé, 中文, العربية"
        expect(described_class.validate_text!(text)).to eq(text)
      end
    end

    context "with empty or nil text" do
      it "accepts nil text and returns empty string" do
        expect(described_class.validate_text!(nil)).to eq("")
      end

      it "accepts empty text and returns empty string" do
        expect(described_class.validate_text!("")).to eq("")
      end

      it "accepts blank text and returns empty string" do
        expect(described_class.validate_text!("   ")).to eq("")
      end
    end

    context "with invalid text" do
      it "rejects text that is too long" do
        long_text = "a" * (MistralTranslator::Security::BasicValidator::MAX_TEXT_LENGTH + 1)
        expect { described_class.validate_text!(long_text) }
          .to raise_error(ArgumentError, /Text too long/)
      end
    end
  end

  describe ".validate_batch!" do
    context "with valid batch" do
      it "accepts valid array of texts" do
        texts = %w[Hello World Test]
        expect(described_class.validate_batch!(texts)).to eq(texts)
      end
    end

    context "with invalid batch" do
      it "rejects nil batch" do
        expect { described_class.validate_batch!(nil) }
          .to raise_error(ArgumentError, "Batch cannot be nil")
      end

      it "rejects non-array batch" do
        expect { described_class.validate_batch!("not an array") }
          .to raise_error(ArgumentError, "Batch must be an array")
      end

      it "rejects empty batch" do
        expect { described_class.validate_batch!([]) }
          .to raise_error(ArgumentError, "Batch cannot be empty")
      end

      it "rejects batch that is too large" do
        large_batch = Array.new(21) { "text" }
        expect { described_class.validate_batch!(large_batch) }
          .to raise_error(ArgumentError, /Batch too large/)
      end
    end
  end
end

RSpec.describe MistralTranslator::Security::BasicRateLimiter do
  let(:rate_limiter) { described_class.new(max_requests: 3, window_seconds: 60) }

  describe "#initialize" do
    it "sets default values" do
      limiter = described_class.new
      expect(limiter.instance_variable_get(:@max_requests)).to eq(50)
      expect(limiter.instance_variable_get(:@window_seconds)).to eq(60)
    end

    it "accepts custom values" do
      limiter = described_class.new(max_requests: 10, window_seconds: 30)
      expect(limiter.instance_variable_get(:@max_requests)).to eq(10)
      expect(limiter.instance_variable_get(:@window_seconds)).to eq(30)
    end
  end

  describe "#wait_and_record!" do
    it "records request when under limit" do
      expect { rate_limiter.wait_and_record! }
        .to change { rate_limiter.instance_variable_get(:@requests).size }.by(1)
    end

    it "waits when at limit" do
      3.times { rate_limiter.wait_and_record! }
      expect(rate_limiter).to receive(:sleep).with(be > 0)
      rate_limiter.wait_and_record!
    end

    it "is thread-safe" do
      # Créer un rate limiter avec une limite plus élevée pour éviter les attentes
      large_limiter = described_class.new(max_requests: 10, window_seconds: 60)

      threads = []
      5.times do
        threads << Thread.new { large_limiter.wait_and_record! }
      end
      threads.each(&:join)

      expect(large_limiter.instance_variable_get(:@requests).size).to eq(5)
    end
  end
end
