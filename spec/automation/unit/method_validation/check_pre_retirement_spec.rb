describe "check_pre_retirement Method Validation" do
  before(:each) { @vm = FactoryGirl.create(:vm_microsoft) }
  after(:each) { @vm.destroy }

  let(:user) do
    FactoryGirl.create(:user_with_group)
  end

  let(:ws) do
    MiqAeEngine.instantiate("/Infrastructure/VM/Retirement/StateMachines/Methods/CheckPreRetirement?" \
                            "Vm::vm=#{@vm.id}#microsoft", user)
  end

  it "returns 'ok' for a vm in powered_off state" do
    @vm.update_attribute(:raw_power_state, "PowerOff")

    expect(ws.root['vm'].power_state).to eq("off")
    expect(ws.root['ae_result']).to eq("ok")
  end

  it "errors for a template" do
    @vm.update_attribute(:template, true)
    expect(@vm.state).to eq("never")

    expect { ws }.to raise_error(MiqAeException::ServiceNotFound)
  end

  it "retries for a vm in powered_on state" do
    @vm.update_attribute(:raw_power_state, "Running")

    expect(ws.root['ae_result']).to eq("retry")
    expect(ws.root['vm'].power_state).to eq("on")
  end
end
