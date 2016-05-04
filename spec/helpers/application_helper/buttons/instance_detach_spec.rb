describe ApplicationHelper::Button::InstanceDetach do
  describe '#disabled?' do
    it "when the detach action is available and volumes are attached then the button is enabled" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(VmCloud.new, :is_available? => true, :number_of => 1)}, {}
      )
      expect(button.disabled?).to be false
    end

    it "when the detach action is unavailable then the button is disabled" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(VmCloud.new, :is_available? => false, :number_of => 1)}, {}
      )
      expect(button.disabled?).to be true
    end

    it "when the record has no attached volumes then the button is disabled" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(VmCloud.new, :is_available? => true, :number_of => 0)}, {}
      )
      expect(button.disabled?).to be true
    end
  end

  describe '#calculate_properties' do
    it "when the detach action is unavailable the button has the error in the title" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(
          VmCloud.new, :is_available? => false, :number_of => 1, :is_available_now_error_message => "unavailable"
        )}, {}
      )
      button.calculate_properties
      expect(button[:title]).to eq("unavailable")
    end

    it "when there are no volumes to detach the button has the error in the title" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(
          VmCloud.new, :is_available? => true, :number_of => 0, :name => "TestVM"
        )}, {}
      )
      button.calculate_properties
      expect(button[:title]).to eq(_("%{model} \"TestVM\" has no attached %{volumes}") % {
        :model   => ui_lookup(:table => 'vm_cloud'),
        :volumes => ui_lookup(:tables => 'cloud_volumes')
      })
    end

    it "when there are volumes to detach and the action is avaiable, the button has no error in the title" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(
          VmCloud.new, :is_available? => true, :number_of => 1
        )}, {}
      )
      button.calculate_properties
      expect(button[:title]).to be nil
    end
  end
end
