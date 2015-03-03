require 'spec_helper'

describe "amazon_pre_retirement Method Validation" do
  before(:each) do
    @zone = FactoryGirl.create(:zone)
    @ems  = FactoryGirl.create(:ems_vmware, :zone => @zone)
    @ebs_hardware = FactoryGirl.create(:hardware, :bitness             => 64,
                                                  :virtualization_type => 'paravirtual',
                                                  :root_device_type    => 'ebs')
    @is_hardware  = FactoryGirl.create(:hardware, :bitness             => 64,
                                                  :virtualization_type => 'paravirtual',
                                                  :root_device_type    => 'instance_store')
    @vm   = FactoryGirl.create(:vm_amazon,
                               :name => "testVM", :power_state => "on", :ems_id => @ems.id,
                               :registered => true)
    @ins  = "/Cloud/VM/Retirement/StateMachines/Methods/PreRetirement"
  end

  it "calls stop for ebs instances" do
    @vm.hardware = @ebs_hardware
    MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#amazon")
    MiqQueue.exists?(:method_name => 'stop', :instance_id => @vm.id, :role => 'ems_operations').should be_true
  end

  it "should not call stop for instance store instances" do
    @vm.hardware = @is_hardware
    MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#amazon")
    MiqQueue.exists?(:method_name => 'stop', :instance_id => @vm.id, :role => 'ems_operations').should be_false
  end
end
