require "spec_helper"
require "util/miq-ipmi"

describe MiqIPMI do
  subject { described_class.new("host", "user", "pass") }

  it "#chassis_status" do
    response = {:result => "System Power         : off\nPower Overload       : false\nPower Interlock      : inactive\nMain Power Fault     : false\nPower Control Fault  : false\nPower Restore Policy : previous\nLast Power Event     : command\nChassis Intrusion    : inactive\nFront-Panel Lockout  : inactive\nDrive Fault          : false\nCooling/Fan Fault    : false\nSleep Button Disable : not allowed\nDiag Button Disable  : allowed\nReset Button Disable : not allowed\nPower Button Disable : allowed\nSleep Button Disabled: false\nDiag Button Disabled : true\nReset Button Disabled: false\nPower Button Disabled: false\n", :value => true}

    result = {
      "System Power"          => "off",
      "Power Overload"        => "false",
      "Power Interlock"       => "inactive",
      "Main Power Fault"      => "false",
      "Power Control Fault"   => "false",
      "Power Restore Policy"  => "previous",
      "Last Power Event"      => "command",
      "Chassis Intrusion"     => "inactive",
      "Front-Panel Lockout"   => "inactive",
      "Drive Fault"           => "false",
      "Cooling/Fan Fault"     => "false",
      "Sleep Button Disable"  => "not allowed",
      "Diag Button Disable"   => "allowed",
      "Reset Button Disable"  => "not allowed",
      "Power Button Disable"  => "allowed",
      "Sleep Button Disabled" => "false",
      "Diag Button Disabled"  => "true",
      "Reset Button Disabled" => "false",
      "Power Button Disabled" => "false"
    }

    expect_any_instance_of(Rubyipmi::Ipmitool::Chassis).to receive(:status).twice.and_return(response)
    expect(subject.chassis_status).to eq(result)
  end

  context "Power Ops" do
    it { expect(subject).to be_connected }

    it "#power_state" do
      expect_any_instance_of(Rubyipmi::Ipmitool::Power).to receive(:status).and_return("off")
      expect(subject.power_state).to eq("off")
    end

    it "#power_on" do
      expect_any_instance_of(Rubyipmi::Ipmitool::Power).to receive(:on).and_return(true)
      expect(subject.power_on).to eq(true)
    end

    it "#power_off" do
      expect_any_instance_of(Rubyipmi::Ipmitool::Power).to receive(:off).and_return(true)
      expect(subject.power_off).to eq(true)
    end

    it "#power_reset" do
      expect_any_instance_of(Rubyipmi::Ipmitool::Power).to receive(:reset).and_return(true)
      expect(subject.power_reset).to eq(true)
    end
  end

  it "#manufacturer" do
    response = {
      "Device ID"                 => "32",
      "Device Revision"           => "1",
      "Firmware Revision"         => "1.57",
      "IPMI Version"              => "2.0",
      "Manufacturer ID"           => "674",
      "Manufacturer Name"         => "DELL Inc",
      "Product ID"                => "256 (0x0100)",
      "Product Name"              => "Unknown (0x100)",
      "Device Available"          => "yes",
      "Provides Device SDRs"      => "yes",
      "Additional Device Support" => ["Sensor Device", "SDR Repository Device", "SEL Device", "FRU Inventory Device", "IPMB Event Receiver", "Bridge", "Chassis Device"],
      "Aux Firmware Rev Info"     => ["0x00", "0x04", "0x39", "0x00"]
    }

    expect_any_instance_of(Rubyipmi::Ipmitool::Bmc).to receive(:info).and_return(response)
    expect(subject.manufacturer).to eq("DELL Inc")
  end

  context "version 1.5" do
    before { described_class.stub(:is_2_0_available?).and_return(false) }
    before { allow_any_instance_of(MiqIPMI).to receive(:chassis_status).and_return({}) }

    it "#interface_mode" do
      subject.interface_mode.should == "lan"
    end

    it "#run_command" do
      MiqUtil.should_receive(:runcmd).with { |cmd| cmd.should include("-I lan") }
      subject.run_command("chassis power status")
    end
  end

  context "version 2.0" do
    before { described_class.stub(:is_2_0_available?).and_return(true) }
    before { allow_any_instance_of(MiqIPMI).to receive(:chassis_status).and_return({}) }

    it "#interface_mode" do
      subject.interface_mode.should == "lanplus"
    end

    it "#run_command" do
      MiqUtil.should_receive(:runcmd).with { |cmd| cmd.should include("-I lanplus") }
      subject.run_command("chassis power status")
    end
  end
end
