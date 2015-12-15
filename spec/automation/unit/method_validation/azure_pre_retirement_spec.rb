require 'spec_helper'

describe "azure_pre_retirement Method Validation" do
  before do
    @user = FactoryGirl.create(:user_with_group)
    @zone = FactoryGirl.create(:zone)
    @ems  = FactoryGirl.create(:ems_azure, :zone => @zone)
    @vm   = FactoryGirl.create(:vm_azure,
                               :name => "AZURE",   :raw_power_state => "VM Running",
                               :ems_id => @ems.id, :registered => true)
    @ins  = "/Cloud/VM/Retirement/StateMachines/Methods/PreRetirement"
  end

  it "call suspend for running instances" do
    MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#Azure", @user)
    MiqQueue.exists?(:method_name => 'stop', :instance_id => @vm.id, :role => 'ems_operations').should be_true
  end

  it "does not call suspend for powered off instances" do
    @vm.update_attributes(:raw_power_state => 'VM Stopped')
    MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#Azure", @user)
    MiqQueue.exists?(:method_name => 'stop', :instance_id => @vm.id, :role => 'ems_operations').should be_false
  end
end
