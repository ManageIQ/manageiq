require 'spec_helper'

describe "amazon_check_pre_retirement Method Validation" do
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
                               :name => "AMZN",    :raw_power_state => "running",
                               :ems_id => @ems.id, :registered => true)
    @ins  = "/Cloud/VM/Retirement/StateMachines/Methods/CheckPreRetirement"
  end

  it "returns 'ok' for instance store instances even with power on" do
    @vm.hardware = @is_hardware
    ws = MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#amazon")
    ws.root['ae_result'].should be == 'ok'
    ws.root['vm'].power_state.should be == 'on'
  end

  it "returns 'retry' for running ebs instances" do
    @vm.hardware = @ebs_hardware
    ws = MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#amazon")
    ws.root['ae_result'].should be == 'retry'
    ws.root['vm'].power_state.should be == 'on'
  end

  it "returns 'ok' for stopped ebs instances" do
    @vm.hardware = @ebs_hardware
    @vm.update_attributes(:raw_power_state => "off")
    ws = MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#amazon")
    ws.root['ae_result'].should be == 'ok'
    ws.root['vm'].power_state.should be == 'off'
  end
end
