describe LinkedCloneVisibilityService do
  let(:subject) { described_class.new }

  describe "#determine_visibility" do
    context "when provision type is vmware" do
      let(:provision_type) { "vmware" }

      context "when linked clone is true" do
        let(:linked_clone) { true }

        it "adds values to the field names to show" do
          expect(subject.determine_visibility(provision_type, linked_clone)).to eq(
            {
              :hide => [],
              :show => [:linked_clone, :snapshot]
            }
          )
        end
      end

      context "when linked clone is not true" do
        let(:linked_clone) { false }

        it "adds values to the field names to hide" do
          expect(subject.determine_visibility(provision_type, linked_clone)).to eq(
            {
              :hide => [:snapshot],
              :show => [:linked_clone]
            }
          )
        end
      end
    end

    context "when provision type is not vmware" do
      let(:provision_type) { nil }
      let(:linked_clone) { nil }

      it "adds values to the field names to hide" do
        expect(subject.determine_visibility(provision_type, linked_clone)).to eq(
          {
            :hide => [:linked_clone, :snapshot],
            :show => []
          }
        )
      end
    end
  end
end
