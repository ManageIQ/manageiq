require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. lib})))
require "appliance_console/service_group"
require "linux_admin"

describe ApplianceConsole::ServiceGroup do
  before do
    @group = described_class.new
    @common_services  = %w{evminit memcached miqtop evmserverd}
    @postgres_service = %w{postgresql92-postgresql}
  end

  it "#postgresql?" do
    expect(described_class.new(:internal_postgresql => true).postgresql?).to be_true
    expect(described_class.new(:internal_postgresql => false).postgresql?).to be_false
    expect(described_class.new.postgresql?).to be_false
  end

  context "postgresql" do
    before do
      @group.stub(:postgresql? => true)
    end

    it "#to_enable" do
      expect(@group.to_enable).to eq(@common_services | @postgres_service)
    end

    it "#to_start" do
      expect(@group.to_start).to eq(@common_services)
    end

    it "#to_disable" do
      expect(@group.to_disable).to eq([])
    end

    it "#to_stop" do
      expect(@group.to_stop).to eq([])
    end
  end

  context "without postgresql" do
    it "#to_enable" do
      expect(@group.to_enable).to eq(@common_services)
    end

    it "#to_start" do
      expect(@group.to_start).to eq(@common_services)
    end

    it "#to_disable" do
      expect(@group.to_disable).to eq(@postgres_service)
    end

    it "#to_stop" do
      expect(@group.to_stop).to eq(@postgres_service)
    end
  end

  shared_examples_for "service management" do |command|
    it "##{command}" do
      LinuxAdmin.should_receive(:run).with("chkconfig", :params => {"--add" => "miqtop"}) if command == "enable"
      expected_calls = @group.send("to_#{command}")

      # Hack until LinuxAdmin::Service start handles detaching.
      if command == "start"
        @group.should_receive(:start_command)
      else
        expected_calls.each do |service|
          LinuxAdmin::Service.should_receive(:new).with(service).and_return(double(command => true))
        end
      end

      @group.send(command)
    end
  end

  include_examples "service management", "enable"
  include_examples "service management", "disable"
  include_examples "service management", "stop"
  include_examples "service management", "start"
end
