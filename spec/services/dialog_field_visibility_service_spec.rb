describe DialogFieldVisibilityService do
  let(:subject) { described_class.new }

  describe "#determine_visibility" do
    let(:subject) do
      described_class.new(
        auto_placement_visibility_service,
      )
    end

    let(:options) do
      {
        :auto_placement_enabled          => auto_placement_enabled,
      }
    end

    let(:auto_placement_visibility_service) { double("AutoPlacementVisibilityService") }
    let(:auto_placement_enabled) { "auto_placement_enabled" }

    before do
      allow(auto_placement_visibility_service).
        to receive(:determine_visibility).with(auto_placement_enabled).and_return(
          {:hide => [:auto_hide], :show => [:auto_show]}
        )
    end

    it "adds the values to the field names to hide and show without duplicates or intersections" do
      expect(subject.determine_visibility(options)).to eq({
        :hide => [
          :auto_hide,
        ],
        :edit => [
          :auto_show,
        ]
      })
    end
  end
end
