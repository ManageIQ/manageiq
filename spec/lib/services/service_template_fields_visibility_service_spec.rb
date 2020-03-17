describe ServiceTemplateFieldsVisibilityService do
  let(:subject) { described_class.new }

  describe "#determine_visibility" do
    context "when service_template_request exists" do
      let(:service_template_request) { "a service template request" }

      it "adds values to field names to hide" do
        expect(subject.determine_visibility(service_template_request)).to eq(
          :hide => %i(vm_description schedule_type schedule_time)
        )
      end
    end

    context "when service_template_request does not exist" do
      let(:service_template_request) { nil }

      it "returns an empty hide/show hash" do
        expect(subject.determine_visibility(service_template_request)).to eq(
          :hide => []
        )
      end
    end
  end
end
