describe ApplicationHelper::Button::InstanceDisassociateFloatingIp do
  describe '#disabled?' do
    it "when the disassociate ip action is available and the instance has floating ips then the button is enabled" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(VmCloud.new, :is_available? => true, :number_of => 1)}, {}
      )
      expect(button.disabled?).to be false
    end

    it "when the disassociate floating ip action is unavailable then the button is disabled" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(VmCloud.new, :is_available? => false, :number_of => 1)}, {}
      )
      expect(button.disabled?).to be true
    end

    it "when the instance is not associated to any floating ips then the button is disabled" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(VmCloud.new, :is_available? => true, :number_of => 0)}, {}
      )
      expect(button.disabled?).to be true
    end
  end

  describe '#calculate_properties' do
    it "when the disassociate floating ip action is unavailable the button has the error in the title" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(
          VmCloud.new, :is_available? => false, :number_of => 1, :is_available_now_error_message => "unavailable"
        )}, {}
      )
      button.calculate_properties
      expect(button[:title]).to eq("unavailable")
    end

    it "when there are no floating ips to associate from the button has the error in the title" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {}, {"record" => object_double(
          VmCloud.new, :is_available? => true, :number_of => 0, :name => "TestVm"
        )}, {}
      )
      button.calculate_properties
      expect(button[:title]).to eq(_("%{instance} \"TestVm\" does not have any associated %{floating_ips}") % {
        :instance     => ui_lookup(:table => 'vm_cloud'),
        :floating_ips => ui_lookup(:tables => 'floating_ip')
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
