require 'spec_helper'

describe "openstack_check_pre_retirement Method Validation" do
  before(:each) do
    @zone = FactoryGirl.create(:zone)
    @ems  = FactoryGirl.create(:ems_vmware, :zone => @zone)
    @vm   = FactoryGirl.create(:vm_openstack,
                               :name => "OOO",     :raw_power_state => "RUNNING",
                               :ems_id => @ems.id, :registered => true)
    @ins  = "/Cloud/VM/Retirement/StateMachines/Methods/CheckPreRetirement"
  end

  it "returns 'retry' for running instances" do
    ws = MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#openstack")
    ws.root['ae_result'].should be == 'retry'
    ws.root['vm'].power_state.should be == 'on'
  end

  it "returns 'ok' for stopped instances" do
    @vm.update_attributes(:raw_power_state => "SHUTOFF")
    ws = MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#openstack")
    ws.root['ae_result'].should be == 'ok'
    ws.root['vm'].power_state.should be == 'off'
  end
end
