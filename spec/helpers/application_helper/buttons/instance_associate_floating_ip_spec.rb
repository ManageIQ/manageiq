describe ApplicationHelper::Button::InstanceAssociateFloatingIp do
  describe '#disabled?' do
    it "when the associate floating ip action is available then the button is not disabled" do
      view_context = setup_view_context_with_sandbox({})
      tenant = object_double(CloudTenant.new, :floating_ips => [1])
      vm = object_double(VmCloud.new, :cloud_tenant => tenant, :supports_associate_floating_ip? => true)
      button = described_class.new(
        view_context, {}, {"record" => vm}, {}
      )
      expect(button.disabled?).to be false
    end

    it "when the associate floating ip action is unavailable then the button is disabled" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(
        view_context, {},
        {"record" => object_double(VmCloud.new, :supports_associate_floating_ip? => false,
                                                :unsupported_reason              => "unavailable")}, {}
      )
      expect(button.disabled?).to be true
    end

    it "when the there are no floating ips available then the button is disabled" do
      view_context = setup_view_context_with_sandbox({})
      tenant = object_double(CloudTenant.new, :floating_ips => [])
      vm = object_double(VmCloud.new, :cloud_tenant => tenant, :supports_associate_floating_ip? => true)
      button = described_class.new(
        view_context, {}, {"record" => vm}, {}
      )
      expect(button.disabled?).to be true
    end
  end

  describe '#calculate_properties' do
    it "when the associate floating ip action is unavailable the button has the error in the title" do
      view_context = setup_view_context_with_sandbox({})
      tenant = object_double(CloudTenant.new, :number_of => 1)
      vm = object_double(VmCloud.new,
                         :supports_associate_floating_ip? => false,
                         :cloud_tenant                    => tenant,
                         :unsupported_reason              => "unavailable")
      button = described_class.new(
        view_context, {}, {"record" => vm}, {}
      )
      button.calculate_properties
      expect(button[:title]).to eq("unavailable")
    end

    it "when there are no floating ips available the button has the error in the title" do
      view_context = setup_view_context_with_sandbox({})
      tenant = object_double(CloudTenant.new, :floating_ips => [])
      vm = object_double(VmCloud.new,
                         :cloud_tenant                    => tenant,
                         :supports_associate_floating_ip? => true)
      button = described_class.new(
        view_context, {}, {"record" => vm}, {}
      )
      button.calculate_properties
      expect(button[:title]).to eq("There are no Floating IPs available to this Instance.")
    end

    it "when the action is available, the button has no error in the title" do
      view_context = setup_view_context_with_sandbox({})
      tenant = object_double(CloudTenant.new, :floating_ips => [1])
      vm = object_double(VmCloud.new,
                         :cloud_tenant                    => tenant,
                         :supports_associate_floating_ip? => true)
      button = described_class.new(
        view_context, {}, {"record" => vm}, {}
      )
      button.calculate_properties
      expect(button[:title]).to be nil
    end
  end
end
