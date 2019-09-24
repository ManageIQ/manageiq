shared_examples_for "Vm operation is available when not powered on" do
  it "when powered on" do
    vm.update(:raw_power_state => power_state_on)
    if vm.respond_to?("supports_#{state}?")
      expect(vm.public_send("supports_#{state}?")).to be_falsey
    else
      expect(vm.is_available?(state)).to be_falsey
    end
  end

  it "when not powered on" do
    vm.update(:raw_power_state => power_state_suspended)
    if vm.respond_to?("supports_#{state}?")
      expect(vm.public_send("supports_#{state}?")).to be_truthy
    else
      expect(vm.is_available?(state)).to be_truthy
    end
  end
end

shared_examples_for "Vm operation is available when powered on" do
  it "when powered on" do
    vm.update(:raw_power_state => power_state_on)
    if vm.respond_to?("supports_#{state}?")
      expect(vm.public_send("supports_#{state}?")).to be_truthy
    else
      expect(vm.is_available?(state)).to be_truthy
    end
  end

  it "when not powered on" do
    vm.update(:raw_power_state => power_state_suspended)
    if vm.respond_to?("supports_#{state}?")
      expect(vm.public_send("supports_#{state}?")).to be_falsey
    else
      expect(vm.is_available?(state)).to be_falsey
    end
  end
end

shared_examples_for "Vm operation is not available" do
  it "is not available" do
    if vm.respond_to?("supports_#{state}?")
      expect(vm.public_send("supports_#{state}?")).to be_falsey
      expect(vm.unsupported_reason(state.to_sym)).to include("not available")
    else
      expect(vm.is_available?(state)).to be_falsey
      expect(vm.is_available_now_error_message(state)).to include("not available")
    end
  end
end
