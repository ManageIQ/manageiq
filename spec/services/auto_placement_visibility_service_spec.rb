describe AutoPlacementVisibilityService do
  let(:subject) { described_class.new }

  describe "#determine_visibility" do
    context "when auto placement is enabled" do
      let(:auto_placement) { true }

      it "adds values to the field names to hide" do
        expect(subject.determine_visibility(auto_placement)).to eq(
          :hide => [
            :placement_host_name,
            :placement_ds_name,
            :host_filter,
            :ds_filter,
            :cluster_filter,
            :placement_cluster_name,
            :rp_filter,
            :placement_rp_name,
            :placement_dc_name
          ],
          :show => []
        )
      end
    end

    context "when auto placement is not enabled" do
      let(:auto_placement) { false }

      it "adds values to the field names to show" do
        expect(subject.determine_visibility(auto_placement)).to eq(
          :hide => [],
          :show => [
            :placement_host_name,
            :placement_ds_name,
            :host_filter,
            :ds_filter,
            :cluster_filter,
            :placement_cluster_name,
            :rp_filter,
            :placement_rp_name,
            :placement_dc_name
          ]
        )
      end
    end
  end
end
