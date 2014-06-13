require "spec_helper"

describe NewWithTypeStiMixin do
  context ".new" do
    it "without type" do
      Host.new.class.should          == Host
      HostRedhat.new.class.should    == HostRedhat
      HostVmware.new.class.should    == HostVmware
      HostVmwareEsx.new.class.should == HostVmwareEsx
    end

    it "with type" do
      Host.new(:type => "Host").class.should          == Host
      Host.new(:type => "HostRedhat").class.should    == HostRedhat
      Host.new(:type => "HostVmware").class.should    == HostVmware
      Host.new(:type => "HostVmwareEsx").class.should == HostVmwareEsx
      HostVmware.new(:type  => "HostVmwareEsx").class.should == HostVmwareEsx

      Host.new("type" => "Host").class.should          == Host
      Host.new("type" => "HostRedhat").class.should    == HostRedhat
      Host.new("type" => "HostVmware").class.should    == HostVmware
      Host.new("type" => "HostVmwareEsx").class.should == HostVmwareEsx
      HostVmware.new("type" => "HostVmwareEsx").class.should == HostVmwareEsx
    end

    context "with invalid type" do
      it "that doesn't exist" do
        lambda { Host.new(:type  => "Xxx") }.should raise_error
        lambda { Host.new("type" => "Xxx") }.should raise_error
      end

      it "that isn't a subclass" do
        lambda { Host.new(:type  => "VmVmware") }.should raise_error
        lambda { Host.new("type" => "VmVmware") }.should raise_error

        lambda { HostVmware.new(:type  => "Host") }.should raise_error
        lambda { HostVmware.new("type" => "Host") }.should raise_error

        lambda { HostVmware.new(:type  => "HostRedhat") }.should raise_error
        lambda { HostVmware.new("type" => "HostRedhat") }.should raise_error
      end
    end
  end
end
