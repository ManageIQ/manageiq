describe MiqEnvironment do
  context "with linux platform" do
    before do
      @old_impl = Sys::Platform::IMPL
      silence_warnings { Sys::Platform::IMPL = :linux }
    end

    after do
      silence_warnings { Sys::Platform::IMPL = @old_impl } if @old_impl
    end

    context "Command" do
      context ".supports_memcached?" do
        it "should run once and cache the result" do
          expect(MiqEnvironment::Command).to receive(:is_linux?).once.and_return(false)
          assert_same_result_every_time(:supports_memcached?, false)
        end
      end

      context ".supports_apache?" do
        it "should run once and cache the result" do
          expect(MiqEnvironment::Command).to receive(:is_appliance?).once.and_return(false)
          assert_same_result_every_time(:supports_apache?, false)
        end
      end

      context ".supports_nohup_and_backgrounding?" do
        it "should run once and cache the result" do
          expect(MiqEnvironment::Command).to receive(:is_appliance?).once.and_return(false)
          assert_same_result_every_time(:supports_nohup_and_backgrounding?, false)
        end
      end

      context ".is_production?" do
        it "should return false if Rails undefined" do
          allow(Object).to receive(:defined?).with(:Rails).and_return(false)
          expect(MiqEnvironment::Command.is_production?).to be_falsey
        end

        it "will return true if linux and /var/www/miq/vmdb exists and cache the result" do
          expect(MiqEnvironment::Command).to receive(:is_linux?).once.and_return(true)
          expect(File).to receive(:exist?).once.and_return(true)
          assert_same_result_every_time(:is_appliance?, true)
        end
      end

      describe ".is_container?" do
        it "returns false if the environment variable is not set" do
          assert_same_result_every_time(:is_container?, false)
        end

        it "returns true if the environment variable is set" do
          ENV["CONTAINER"] = "true"
          assert_same_result_every_time(:is_container?, true)
          ENV.delete("CONTAINER")
        end
      end
    end
  end

  def assert_same_result_every_time(method, expected)
    2.times { expect(MiqEnvironment::Command.send(method)).to eq(expected) }
  end
end
