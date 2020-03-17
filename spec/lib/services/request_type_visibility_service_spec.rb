describe RequestTypeVisibilityService do
  let(:subject) { described_class.new }

  describe "#determine_visibility" do
    context "when the request type is 'clone_to_template'" do
      let(:request_type) { :clone_to_template }

      it "returns the values to be hidden" do
        expect(subject.determine_visibility(request_type)).to eq(:hide => %i(vm_filter vm_auto_start))
      end
    end

    context "when the request type is 'clone_to_vm'" do
      let(:request_type) { :clone_to_vm }

      it "returns the values to be hidden" do
        expect(subject.determine_visibility(request_type)).to eq(:hide => [:vm_filter])
      end
    end

    context "when the request type is anything else" do
      let(:request_type) { :potato }

      it "returns an empty list of values to be hidden" do
        expect(subject.determine_visibility(request_type)).to eq(:hide => [])
      end
    end
  end
end
