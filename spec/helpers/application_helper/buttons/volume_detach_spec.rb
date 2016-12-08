describe ApplicationHelper::Button::VolumeDetach do
  describe '#disabled?' do
    it "when the detach action is available and the volume is attached to instances then the button is enabled" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(CloudVolume.new, :is_available? => true, :number_of => 1)}, {}
      )
      expect(button.disabled?).to be false
    end

    it "when the detach action is unavailable then the button is disabled" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {},
        {"record" => object_double(CloudVolume.new, :is_available?                  => false,
                                                    :number_of                      => 1,
                                                    :is_available_now_error_message => "unavailable")}, {}
      )
      expect(button.disabled?).to be true
    end

    it "when the volume is not attached to any instances then the button is disabled" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(CloudVolume.new, :is_available? => true,
                                                                      :number_of     => 0,
                                                                      :name          => '')}, {}
      )
      expect(button.disabled?).to be true
    end
  end

  describe '#calculate_properties' do
    it "when the detach action is unavailable the button has the error in the title" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(
          CloudVolume.new, :is_available? => false, :number_of => 1, :is_available_now_error_message => "unavailable"
        )}, {}
      )
      button.calculate_properties
      expect(button[:title]).to eq("unavailable")
    end

    it "when there are no instances to detach from the button has the error in the title" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(
          CloudVolume.new, :is_available? => true, :number_of => 0, :name => "TestVolume"
        )}, {}
      )
      button.calculate_properties
      expect(button[:title]).to eq(_("%{model} \"TestVolume\" is not attached to any %{instances}") % {
        :model     => ui_lookup(:table => 'cloud_volume'),
        :instances => ui_lookup(:tables => 'vm_cloud')
      })
    end

    it "when there are instances to detach from and the action is available, the button has no error in the title" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(
          CloudVolume.new, :is_available? => true, :number_of => 1
        )}, {}
      )
      button.calculate_properties
      expect(button[:title]).to be nil
    end
  end
end
