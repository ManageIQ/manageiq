describe ApplicationHelper::Button::VolumeAttach do
  describe '#disabled?' do
    it "when the attach action is available then the button is not disabled" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(CloudVolume.new, :is_available? => true)}, {}
      )
      expect(button.disabled?).to be false
    end

    it "when the attach action is unavailable then the button is disabled" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {},
        {"record" => object_double(CloudVolume.new, :is_available?                  => false,
                                                    :is_available_now_error_message => "unavailable")}, {}
      )
      expect(button.disabled?).to be true
    end
  end

  describe '#calculate_properties' do
    it "when the attach action is unavailable the button has the error in the title" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(
          CloudVolume.new, :is_available? => false, :is_available_now_error_message => "unavailable")}, {}
      )
      button.calculate_properties
      expect(button[:title]).to eq("unavailable")
    end

    it "when the action is avaiable, the button has no error in the title" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(CloudVolume.new, :is_available? => true)}, {}
      )
      button.calculate_properties
      expect(button[:title]).to be nil
    end
  end
end
