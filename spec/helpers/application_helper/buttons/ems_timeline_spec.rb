describe ApplicationHelper::Button::EmsTimeline do
  describe '#disabled?' do
    it "when the timeline action is available then the button is not disabled" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(VmCloud.new, :supports_timeline? => true, :has_events? => true)}, {}
      )
      expect(button.disabled?).to be false
    end

    it "when the timeline action is unavailable then the button is disabled" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(VmCloud.new, :supports_timeline? => false, :has_events? => false)}, {}
      )
      expect(button.disabled?).to be true
    end
  end

  describe '#calculate_properties' do
    it "when the timeline action is unavailable the button has the error in the title" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(VmCloud.new, :supports_timeline? => false, :has_events? => false)}, {}
      )
      button.calculate_properties
      expect(button[:title]).to eq("No Timeline data has been collected for this Provider")
    end

    it "when the timeline is available, the button has no error in the title" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(VmCloud.new, :supports_timeline? => true, :has_events? => true)}, {}
      )
      button.calculate_properties
      expect(button[:title]).to be nil
    end
  end
end
