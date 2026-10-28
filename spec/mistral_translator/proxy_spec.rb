# frozen_string_literal: true

RSpec.describe MistralTranslator::Proxy do
  let(:host) { "api.mistral.ai" }

  describe ".resolve" do
    it "returns nil without a proxy setting" do
      expect(described_class.resolve(nil, host: host, env: { "HTTPS_PROXY" => "http://p:1" })).to be_nil
    end

    it "accepts a String or a URI" do
      expect(described_class.resolve("http://proxy:3128", host: host).to_s).to eq("http://proxy:3128")
      expect(described_class.resolve(URI("https://proxy:8443"), host: host).to_s).to eq("https://proxy:8443")
    end

    context "with :env" do
      it "prefers HTTPS_PROXY over HTTP_PROXY" do
        env = { "HTTPS_PROXY" => "http://secure:3128", "HTTP_PROXY" => "http://plain:3128" }

        expect(described_class.resolve(:env, host: host, env: env).host).to eq("secure")
      end

      it "reads lowercase variables and falls back to HTTP_PROXY" do
        expect(described_class.resolve(:env, host: host, env: { "http_proxy" => "http://plain:3128" }).host)
          .to eq("plain")
      end

      it "returns nil when no variable is set" do
        expect(described_class.resolve(:env, host: host, env: { "HTTPS_PROXY" => " " })).to be_nil
      end

      it "honours NO_PROXY" do
        proxy = { "HTTPS_PROXY" => "http://proxy:3128" }

        %w[* api.mistral.ai .mistral.ai mistral.ai *.mistral.ai api.mistral.ai:443].each do |no_proxy|
          expect(described_class.resolve(:env, host: host, env: proxy.merge("NO_PROXY" => no_proxy))).to be_nil
        end
        expect(described_class.resolve(:env, host: host,
                                             env: proxy.merge("NO_PROXY" => "localhost,example.com"))).not_to be_nil
        expect(described_class.resolve(:env, host: host, env: proxy.merge("NO_PROXY" => "notmistral.ai"))).not_to be_nil
      end
    end
  end

  describe ".validate!" do
    it "rejects a non-http URL without echoing it" do
      expect { described_class.validate!("socks5://user:hunter2@proxy:1080") }.to raise_error(
        MistralTranslator::ConfigurationError
      ) { |error| expect(error.message).not_to include("hunter2") }
    end

    it "rejects a malformed URL without echoing it" do
      expect { described_class.validate!("http://user:hunter2@pro xy") }.to raise_error(
        MistralTranslator::ConfigurationError
      ) { |error| expect(error.message).not_to include("hunter2") }
    end
  end
end
