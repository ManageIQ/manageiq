shared_examples_for "Vm operation is available when not powered on" do
  it "when powered on" do
    vm.update(:raw_power_state => power_state_on)
    expect(vm.supports?(state.to_sym)).to be_falsey
  end

  it "when not powered on" do
    vm.update(:raw_power_state => power_state_suspended)
    expect(vm.supports?(state.to_sym)).to be_truthy
  end
end

shared_examples_for "Vm operation is available when powered on" do
  it "when powered on" do
    vm.update(:raw_power_state => power_state_on)
    expect(vm.supports?(state.to_sym)).to be_truthy
  end

  it "when not powered on" do
    vm.update(:raw_power_state => power_state_suspended)
    expect(vm.supports?(state.to_sym)).to be_falsey
  end
end

shared_examples_for "Vm operation is not available" do
  it "is not available" do
    expect(vm.supports?(state.to_sym)).to be_falsey
    expect(vm.unsupported_reason(state.to_sym)).to include("not available")
  end
end
