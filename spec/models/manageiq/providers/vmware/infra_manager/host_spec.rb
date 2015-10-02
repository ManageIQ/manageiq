require "spec_helper"

describe ManageIQ::Providers::Vmware::InfraManager::Host do
  before(:each) do
    @host = FactoryGirl.create(:host_vmware)
  end

  context "#reserve_next_available_vnc_port" do
    context "without EMS defaults set" do
      before(:each) do
        @ems = FactoryGirl.create(:ems_vmware, :host_default_vnc_port_start => nil, :host_default_vnc_port_end => nil)
        @host.ext_management_system = @ems
      end

      it "normal case" do
        @host.update_attributes(:next_available_vnc_port => 5901)

        @host.reserve_next_available_vnc_port.should == 5901
        @host.next_available_vnc_port.should == 5902
      end

      it "with last value of nil" do
        @host.update_attributes(:next_available_vnc_port => nil)

        @host.reserve_next_available_vnc_port.should == 5900
        @host.next_available_vnc_port.should == 5901
      end

      it "with last value at end of range" do
        @host.update_attributes(:next_available_vnc_port => 5999)

        @host.reserve_next_available_vnc_port.should == 5999
        @host.next_available_vnc_port.should == 5900
      end

      it "with last value before start of range" do
        @host.update_attributes(:next_available_vnc_port => 5899)

        @host.reserve_next_available_vnc_port.should == 5900
        @host.next_available_vnc_port.should == 5901
      end

      it "with last value after end of range" do
        @host.update_attributes(:next_available_vnc_port => 6000)

        @host.reserve_next_available_vnc_port.should == 5900
        @host.next_available_vnc_port.should == 5901
      end
    end

    context "with EMS defaults set" do
      before(:each) do
        @ems = FactoryGirl.create(:ems_vmware, :host_default_vnc_port_start => 5925, :host_default_vnc_port_end => 5930)
        @host.ext_management_system = @ems
      end

      it "normal case" do
        @host.update_attributes(:next_available_vnc_port => 5926)

        @host.reserve_next_available_vnc_port.should == 5926
        @host.next_available_vnc_port.should == 5927
      end

      it "with last value of nil" do
        @host.update_attributes(:next_available_vnc_port => nil)

        @host.reserve_next_available_vnc_port.should == 5925
        @host.next_available_vnc_port.should == 5926
      end

      it "with last value at end of range" do
        @host.update_attributes(:next_available_vnc_port => 5930)

        @host.reserve_next_available_vnc_port.should == 5930
        @host.next_available_vnc_port.should == 5925
      end

      it "with last value before start of range" do
        @host.update_attributes(:next_available_vnc_port => 5924)

        @host.reserve_next_available_vnc_port.should == 5925
        @host.next_available_vnc_port.should == 5926
      end

      it "with last value after end of range" do
        @host.update_attributes(:next_available_vnc_port => 5931)

        @host.reserve_next_available_vnc_port.should == 5925
        @host.next_available_vnc_port.should == 5926
      end
    end
  end
end
