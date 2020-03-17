describe SysprepAutoLogonVisibilityService do
  let(:subject) { described_class.new }

  describe "#determine_visibility" do
    context "when sysprep_auto_logon is false" do
      let(:sysprep_auto_logon) { false }

      it "adds values to the field names to hide" do
        expect(subject.determine_visibility(sysprep_auto_logon)).to eq(
          :hide => [:sysprep_auto_logon_count],
          :edit => []
        )
      end
    end

    context "when sysprep auto logon is true" do
      let(:sysprep_auto_logon) { true }

      it "adds values to the field names to edit" do
        expect(subject.determine_visibility(sysprep_auto_logon)).to eq(
          :hide => [],
          :edit => [:sysprep_auto_logon_count]
        )
      end
    end
  end
end
