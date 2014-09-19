shared_examples_for "Vm operation is available when not powered on" do
  it "when powered on" do
    vm.update_attributes(:raw_power_state => power_state_on)
    vm.is_available?(state).should be_false
  end

  it "when not powered on" do
    vm.update_attributes(:raw_power_state => power_state_suspended)
    vm.is_available?(state).should be_true
  end
end

shared_examples_for "Vm operation is available when powered on" do
  it "when powered on" do
    vm.update_attributes(:raw_power_state => power_state_on)
    vm.is_available?(state).should be_true
  end

  it "when not powered on" do
    vm.update_attributes(:raw_power_state => power_state_suspended)
    vm.is_available?(state).should be_false
  end
end

shared_examples_for "Vm operation is not available" do
  it "is not available" do
    vm.is_available?(state).should be_false
    vm.is_available_now_error_message(state).should include("not available")
  end
end
