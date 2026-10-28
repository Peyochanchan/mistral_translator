# frozen_string_literal: true

RSpec.describe MistralTranslator::Proxy do
  let(:host) { "api.mistral.ai" }

  describe ".resolve" do
    it "returns nil without a proxy setting" do
      expect(described_class.resolve(nil, host: host, env: { "HTTPS_PROXY" => "http://p:1" })).to be_nil
    end

    it "accepts a String or a URI" do
      expect(described_class.resolve("http://proxy:3128", host: host).to_s).to eq("http://proxy:3128")
      expect(described_class.resolve(URI("http://proxy:8080"), host: host).to_s).to eq("http://proxy:8080")
    end

    it "turns a generic URI into the URI::HTTP that net-http-persistent expects" do
      generic = URI::Generic.build(scheme: "http", host: "proxy", port: 3128)

      expect(described_class.resolve(generic, host: host)).to be_a(URI::HTTP)
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

      it "ignores surrounding whitespace" do
        expect(described_class.resolve(:env, host: host, env: { "HTTPS_PROXY" => "http://proxy:3128\n" }).host)
          .to eq("proxy")
      end

      it "does not let an empty lowercase variable hide the uppercase one" do
        env = { "https_proxy" => "", "HTTPS_PROXY" => "http://proxy:3128", "no_proxy" => "", "NO_PROXY" => "*" }

        expect(described_class.resolve(:env, host: host, env: env)).to be_nil
      end

      it "applies a NO_PROXY entry with a port only to the API port" do
        proxy = { "HTTPS_PROXY" => "http://proxy:3128" }

        expect(described_class.resolve(:env, host: host, env: proxy.merge("NO_PROXY" => "api.mistral.ai:8080")))
          .not_to be_nil
        expect(described_class.resolve(:env, host: "API.Mistral.AI", env: proxy.merge("NO_PROXY" => "api.mistral.ai")))
          .to be_nil
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
    it "rejects an https proxy, which would receive its credentials in clear" do
      expect { described_class.validate!("https://user:hunter2@proxy:443") }.to raise_error(
        MistralTranslator::ConfigurationError, %r{http://}
      ) { |error| expect(error.message).not_to include("hunter2") }
    end

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
