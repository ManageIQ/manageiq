describe SysprepCustomSpecVisibilityService do
  let(:subject) { described_class.new }

  describe "#determine_visibility" do
    context "when sysprep custom spec is not blank" do
      let(:sysprep_custom_spec) { "foo" }

      it "adds values to the field names to hide" do
        expect(subject.determine_visibility(sysprep_custom_spec)).to eq(
          :hide => [:sysprep_spec_override],
          :show => []
        )
      end
    end

    context "when sysprep custom spec is blank" do
      let(:sysprep_custom_spec) { nil }

      it "adds values to the field names to show" do
        expect(subject.determine_visibility(sysprep_custom_spec)).to eq(
          :hide => [],
          :show => [:sysprep_spec_override]
        )
      end
    end
  end
end
