require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. lib})))
require "appliance_console/service_group"
require "linux_admin"

describe ApplianceConsole::ServiceGroup do
  let(:group)             { described_class.new }
  let(:common_services)   { %w(evminit memcached miqtop evmserverd) }
  let(:postgres_service)  { %w(postgresql92-postgresql) }

  describe "#postgresql?" do
    it { expect(group).not_to be_postgresql }

    context "when internal postgres" do
      let(:group) { described_class.new(:internal_postgresql => true) }
      it { expect(group).to be_postgresql }
    end

    context "when not internal postgres" do
      let(:group) { described_class.new(:internal_postgresql => false) }
      it { expect(group).not_to be_postgresql }
    end
  end

  context "postgresql" do
    let(:group) { described_class.new(:internal_postgresql => true) }

    it "#to_enable" do
      expect(group.to_enable).to eq(common_services | postgres_service)
    end

    it "#to_start" do
      expect(group.to_start).to eq(common_services)
    end

    it "#to_disable" do
      expect(group.to_disable).to eq([])
    end

    it "#to_stop" do
      expect(group.to_stop).to eq([])
    end
  end

  context "without postgresql" do
    it "#to_enable" do
      expect(group.to_enable).to eq(common_services)
    end

    it "#to_start" do
      expect(group.to_start).to eq(common_services)
    end

    it "#to_disable" do
      expect(group.to_disable).to eq(postgres_service)
    end

    it "#to_stop" do
      expect(group.to_stop).to eq(postgres_service)
    end
  end

  # this is private, but since we are stubbing it, make sure it works
  context "#enable_miqtop" do
    it "calls chkconfig" do
      expect(LinuxAdmin).to receive(:run).with("chkconfig", :params => {"--add" => "miqtop"})
      group.send(:enable_miqtop)
    end
  end

  # this is private, but since we are stubbing it, make sure it works
  context "#run_service" do
    it "invokes LinuxAdmin service call" do
      stub = double
      expect(stub).to receive('start').and_return(true)
      expect(LinuxAdmin::Service).to receive(:new).with('service').and_return(stub)
      group.send(:run_service, 'service', 'start')
    end
  end

  # this is private, but since we are stubbing it, make sure it works
  context "#detached_service" do
    it "invokes Spawn" do
      spwn = double
      expect(Kernel).to receive(:spawn).with(
        "/sbin/service service start", [:out, :err] => ["/dev/null", "w"]
      ).and_return(spwn)
      expect(Process).to receive(:detach).with(spwn)

      group.send(:run_detached_service, "service", "start")
    end
  end

  shared_examples_for "service management" do |command|
    it "##{command}" do
      expect(group).to receive(:enable_miqtop) if command == "enable"

      expected_calls = group.send("to_#{command}")

      # Hack until LinuxAdmin::Service start handles detaching.
      if command == "start"
        group.should_receive(:start_command)
      else
        expected_calls.each do |service|
          expect(group).to receive(:run_service).with(service, command).and_return(true)
        end
      end

      group.send(command)
    end
  end

  include_examples "service management", "enable"
  include_examples "service management", "disable"
  include_examples "service management", "stop"
  include_examples "service management", "start"
end
