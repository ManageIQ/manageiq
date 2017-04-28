describe PowerState do
  let(:partial_power_states) { %w(on on off on) }
  let(:common_power_states) { %w(on on on on) }
  let(:service) { FactoryGirl.create(:service) }
  let(:options) { { :power_status => "starting" } }

  context "#{described_class}.current" do
    it "returns the current power_state if all states match" do
      expect(service).to receive(:power_states).and_return(common_power_states)

      expect(PowerState.current(options, service)).to eq "on"
    end

    it "returns the partial power_state if some of the states match" do
      allow(service).to receive(:power_states).and_return(partial_power_states)
      expect(service).to receive(:composite?).and_return(true).exactly(4).times
      expect(service).to receive(:atomic?).and_return(false).exactly(4).times

      expect(PowerState.current(options, service)).to eq "partial_on"
    end
  end

  context "#partialize" do
    it "partializes the state with the most entries" do
      allow(service).to receive(:power_states).and_return(partial_power_states)
      power_state = PowerState.new(options, service)
      expect(power_state.partialize).to eq "partial_on"
    end

    it "partializes any state that has the most entries" do
      random_list = %w(blah blah test unknown)
      allow(service).to receive(:power_states).and_return(random_list)
      power_state = PowerState.new(options, service)

      expect(power_state.partialize).to eq "partial_blah"
    end
  end
end
