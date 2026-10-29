# frozen_string_literal: true

RSpec.describe MistralTranslator::Retries do
  let(:requester) { Class.new { include MistralTranslator::Retries }.new }

  let(:waits) { [] }

  before { allow(requester).to receive(:sleep) { |seconds| waits << seconds } }

  def run(&)
    requester.send(:with_retries, operation: "translation", subject: "fr->en", &)
  end

  it "returns the block result and passes the attempt number" do
    attempts = []
    result = run do |attempt|
      attempts << attempt
      raise MistralTranslator::EmptyTranslationError if attempt < 2

      "Hello"
    end

    expect(result).to eq("Hello")
    expect(attempts).to eq([0, 1, 2])
    expect(waits).to eq([2, 4])
  end

  it "raises an unusable response after the last retry" do
    calls = 0

    expect do
      run do
        calls += 1
        raise MistralTranslator::InvalidResponseError, "No JSON in translation response"
      end
    end.to raise_error(MistralTranslator::InvalidResponseError)
    expect(calls).to eq(MistralTranslator::Retries::RETRY_COUNT + 1)
    expect(waits).to eq([2, 4, 8])
  end

  it "waits a fixed delay on rate limits" do
    expect { run { raise MistralTranslator::RateLimitError } }.to raise_error(MistralTranslator::RateLimitError)
    expect(waits).to eq([2, 2, 2])
  end

  it "does not retry other errors" do
    expect { run { raise MistralTranslator::AuthenticationError } }.to raise_error(MistralTranslator::AuthenticationError)
    expect(waits).to be_empty
  end

  it "logs the retry without the request content" do
    allow(MistralTranslator::Logger).to receive(:warn_once)

    run do |attempt|
      raise MistralTranslator::EmptyTranslationError, "Empty translation" if attempt.zero?

      "Hello"
    end

    expect(MistralTranslator::Logger).to have_received(:warn_once)
      .with("translation retry 1/3 for fr->en in 2s: Empty translation",
            key: "translation_retry_fr->en_MistralTranslator::EmptyTranslationError", sensitive: false, ttl: 120)
  end
end
