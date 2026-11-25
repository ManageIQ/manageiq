RSpec.describe MiqWebServerRunnerMixin do
  let(:base_class) do
    Class.new do
      def run
      end
    end
  end

  let(:runner_class) do
    Class.new(base_class) do
      include MiqWebServerRunnerMixin

      def worker
        Struct.new(:rails_server_options).new({})
      end

      def start_rails_server(_options)
      end
    end
  end

  describe "#run" do
    it "verifies the memcached version when using the cache session store" do
      stub_settings_merge(:server => {:session_store => "cache"})

      expect(MiqMemcached).to receive(:verify_version)

      runner_class.new.run
    end

    it "does not verify the memcached version for other session stores" do
      stub_settings_merge(:server => {:session_store => "sql"})

      expect(MiqMemcached).not_to receive(:verify_version)

      runner_class.new.run
    end
  end
end
