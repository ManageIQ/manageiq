shared_examples_for "Vm operation is supported when not powered on" do
  it "when powered on" do
    vm.update_attributes(:raw_power_state => power_state_on)
    vm.supports_operation?(state).should be_false
  end

  it "when not powered on" do
    vm.update_attributes(:raw_power_state => power_state_suspended)
    vm.supports_operation?(state).should be_true
  end
end

shared_examples_for "Vm operation is supported when powered on" do
  it "when powered on" do
    vm.update_attributes(:raw_power_state => power_state_on)
    vm.supports_operation?(state).should be_true
  end

  it "when not powered on" do
    vm.update_attributes(:raw_power_state => power_state_suspended)
    vm.supports_operation?(state).should be_false
  end
end

shared_examples_for "Vm operation is not supported" do
  it "is not available" do
    vm.supports_operation?(state).should be_false
    vm.unavailability_reason(state).should include("not available")
  end
end
