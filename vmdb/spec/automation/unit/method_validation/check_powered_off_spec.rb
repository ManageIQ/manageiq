require "spec_helper"

describe "check_powered_off Method Validation" do

  before(:each) { @vm = FactoryGirl.create(:vm_vmware) }
  after(:each) { @vm.destroy }

  let(:ws) { MiqAeEngine.instantiate("/Infrastructure/VM/Retirement/StateMachines/Methods/CheckPoweredOff?Vm::vm=#{@vm.id}") }

  it "returns 'ok' for a vm in powered_off state" do
    @vm.update_attribute(:state, "off")

    ws.root['vm']['power_state'].should == "off"
    ws.root['ae_result'].should         == "ok"
  end

  it "errors for a template" do
    @vm.update_attribute(:template, true)
    @vm.state.should    == "never"

    lambda { ws }.should raise_error(MiqAeException::ServiceNotFound)
  end

  it "retries for a vm in powered_on state" do
    @vm.update_attributes(:type => "VmRedhat", :state => "on")

    ws.root['ae_result'].should         == "retry"
    ws.root['vm']['power_state'].should == "on"
  end

end

