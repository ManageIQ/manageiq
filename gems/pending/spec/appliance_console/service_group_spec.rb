require "spec_helper"
require "appliance_console/service_group"
require "linux_admin"

describe ApplianceConsole::ServiceGroup do
  let(:group)             { described_class.new }
  let(:common_services)   { %w(evminit memcached miqtop evmserverd) }

  before do
    PostgresAdmin.stub(:service_name => "postgresql")
  end

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

  describe "#enable" do
    let(:group) { described_class.new(:internal_postgresql => false) }

    it "enables all but postgres" do
      expect(group).to receive(:enable_miqtop)
      common_services.each do |service|
        expect_run_service(service, "enable")
      end

      group.enable
    end

    context "with postgres" do
      let(:group) { described_class.new(:internal_postgresql => true) }

      it "enables all including postgres" do
        expect(group).to receive(:enable_miqtop)
        common_services.each do |service|
          expect_run_service(service, "enable")
        end
        expect_run_service(PostgresAdmin.service_name, "enable")

        group.enable
      end
    end
  end

  describe "#start" do
    let(:group) { described_class.new(:internal_postgresql => false) }

    it "starts all but postgres" do
      common_services.each do |service|
        expect_run_detached_service(service, "start")
      end

      group.start
    end

    context "with postgres" do
      let(:group) { described_class.new(:internal_postgresql => true) }

      it "starts all including postgres" do
        common_services.each do |service|
          expect_run_detached_service(service, "start")
        end

        group.start
      end
    end
  end

  describe "#disable" do
    let(:group) { described_class.new(:internal_postgresql => false) }

    it "disables postgres" do
      expect_run_service(PostgresAdmin.service_name, "disable")

      group.disable
    end

    context "with postgres" do
      let(:group) { described_class.new(:internal_postgresql => true) }

      it "does nothing" do
        expect_no_service_calls

        group.disable
      end
    end
  end

  describe "#stop" do
    let(:group) { described_class.new(:internal_postgresql => false) }

    it "stops postgres" do
      expect_run_service(PostgresAdmin.service_name, "stop")

      group.stop
    end

    context "with postgres" do
      let(:group) { described_class.new(:internal_postgresql => true) }

      it "stops nothing" do
        expect_no_service_calls

        group.stop
      end
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

  private

  def expect_no_service_calls
    expect(group).not_to receive(:run_service)
  end

  def expect_run_detached_service(service, command)
    expect(group).to receive(:run_detached_service).with(service, command)
  end

  def expect_run_service(service, command)
    expect(group).to receive(:run_service).with(service, command)
  end
end
