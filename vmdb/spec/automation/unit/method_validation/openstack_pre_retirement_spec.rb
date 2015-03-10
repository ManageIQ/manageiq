require 'spec_helper'

describe "openstack_pre_retirement Method Validation" do
  before(:each) do
    @zone = FactoryGirl.create(:zone)
    @ems  = FactoryGirl.create(:ems_vmware, :zone => @zone)
    @vm   = FactoryGirl.create(:vm_openstack,
                               :name => "OOO",     :raw_power_state => "RUNNING",
                               :ems_id => @ems.id, :registered => true)
    @ins  = "/Cloud/VM/Retirement/StateMachines/Methods/PreRetirement"
  end

  it "call suspend for running instances" do
    MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#Openstack")
    MiqQueue.exists?(:method_name => 'suspend', :instance_id => @vm.id, :role => 'ems_operations').should be_true
  end

  it "does not call suspend for powered off instances" do
    @vm.update_attributes(:raw_power_state => 'SHUTOFF')
    MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#Openstack")
    MiqQueue.exists?(:method_name => 'suspend', :instance_id => @vm.id, :role => 'ems_operations').should be_false
  end
end
