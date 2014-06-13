require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. util})))
require 'miq-ipmi'

describe MiqIPMI do
  before(:each) do
    MiqIPMI.any_instance.stub(:chassis_status).and_return({})
  end

  context "version 1.5" do
    before(:each) do
      subject.class.stub(:is_2_0_available?).and_return(false)
    end

    it "#interface_mode" do
      subject.interface_mode.should == "lan"
    end

    it "#run_command" do
      MiqUtil.should_receive(:runcmd).with { |cmd| cmd.should include("-I lan") }
      subject.run_command("chassis power status")
    end
  end

  context "version 2.0" do
    before(:each) do
      subject.class.stub(:is_2_0_available?).and_return(true)
    end

    it "#interface_mode" do
      subject.interface_mode.should == "lanplus"
    end

    it "#run_command" do
      MiqUtil.should_receive(:runcmd).with { |cmd| cmd.should include("-I lanplus") }
      subject.run_command("chassis power status")
    end
  end

end
