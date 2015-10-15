require "spec_helper"

describe "check_powered_off Method Validation" do
  before(:each) { @vm = FactoryGirl.create(:vm_vmware) }
  after(:each) { @vm.destroy }

  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:ws) { MiqAeEngine.instantiate("/Infrastructure/VM/Retirement/StateMachines/Methods/CheckPoweredOff?Vm::vm=#{@vm.id}", user) }

  it "returns 'ok' for a vm in powered_off state" do
    @vm.update_attribute(:raw_power_state, "poweredOff")

    ws.root['vm'].power_state.should be == "off"
    ws.root['ae_result'].should be == "ok"
  end

  it "errors for a template" do
    @vm.update_attribute(:template, true)
    @vm.state.should be == "never"

    -> { ws }.should raise_error(MiqAeException::ServiceNotFound)
  end

  it "retries for a vm in powered_on state" do
    @vm.update_attribute(:raw_power_state, "poweredOn")

    ws.root['ae_result'].should be == "retry"
    ws.root['vm'].power_state.should be == "on"
  end
end
