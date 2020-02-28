describe LinkedCloneVisibilityService do
  let(:subject) { described_class.new }

  describe "#determine_visibility" do
    context "when provision type is vmware" do
      let(:provision_type) { "vmware" }

      context "when there are snapshots to show" do
        let(:snapshot_count) { 1 }

        context "when linked clone is true" do
          let(:linked_clone) { true }

          it "adds values to the field names to edit" do
            expect(subject.determine_visibility(provision_type, linked_clone, snapshot_count)).to eq(
              :hide => [],
              :edit => %i(linked_clone snapshot),
              :show => []
            )
          end
        end

        context "when linked clone is not true" do
          let(:linked_clone) { false }

          it "adds values to the field names to hide" do
            expect(subject.determine_visibility(provision_type, linked_clone, snapshot_count)).to eq(
              :hide => [:snapshot],
              :edit => [:linked_clone],
              :show => []
            )
          end
        end
      end

      context "when there are no snapshots to show" do
        let(:snapshot_count) { 0 }
        let(:linked_clone) { "potato" }

        it "adds values to the field names to hide and show" do
          expect(subject.determine_visibility(provision_type, linked_clone, snapshot_count)).to eq(
            :hide => [:snapshot],
            :edit => [],
            :show => [:linked_clone]
          )
        end
      end
    end

    context "when provision type is not vmware" do
      let(:provision_type) { nil }
      let(:linked_clone) { nil }
      let(:snapshot_count) { "potato" }

      it "adds values to the field names to hide" do
        expect(subject.determine_visibility(provision_type, linked_clone, snapshot_count)).to eq(
          :hide => %i(linked_clone snapshot),
          :edit => [],
          :show => []
        )
      end
    end
  end
end
