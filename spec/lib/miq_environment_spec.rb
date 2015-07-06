require "spec_helper"

describe MiqEnvironment do
  context "with linux platform" do
    before(:each) do
      @old_impl = Platform::IMPL
      silence_warnings { Platform::IMPL = :linux }
    end

    after(:each) do
      silence_warnings { Platform::IMPL = @old_impl } if @old_impl
    end

    context "Command" do
      context ".supports_memcached?" do
        it "should run once and cache the result" do
          MiqEnvironment::Command.should_receive(:is_linux?).once.and_return(false)
          assert_same_result_every_time(:supports_memcached?, false)
        end
      end

      context ".supports_apache?" do
        it "should run once and cache the result" do
          MiqEnvironment::Command.should_receive(:is_appliance?).once.and_return(false)
          assert_same_result_every_time(:supports_apache?, false)
        end
      end

      context ".supports_nohup_and_backgrounding?" do
        it "should run once and cache the result" do
          MiqEnvironment::Command.should_receive(:is_appliance?).once.and_return(false)
          assert_same_result_every_time(:supports_nohup_and_backgrounding?, false)
        end
      end

      context ".is_production?" do
        it "should return false if Rails undefined" do
          Object.stub(:defined?).with(:Rails).and_return(false)
          expect(MiqEnvironment::Command.is_production?).to be_false
        end

        it "will return true if linux and /var/www/miq/vmdb exists and cache the result" do
          MiqEnvironment::Command.should_receive(:is_linux?).once.and_return(true)
          File.should_receive(:exist?).once.and_return(true)
          assert_same_result_every_time(:is_appliance?, true)
        end
      end
    end
  end

  def assert_same_result_every_time(method, expected)
    2.times { expect(MiqEnvironment::Command.send(method)).to eq(expected) }
  end
end
