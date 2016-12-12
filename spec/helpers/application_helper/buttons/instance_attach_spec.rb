describe ApplicationHelper::Button::InstanceAttach do
  describe '#disabled?' do
    it "when there are available volumes, then the button is enabled" do
      view_context = setup_view_context_with_sandbox({})

      tenant = FactoryGirl.create(:cloud_tenant_openstack)
      volume = FactoryGirl.create(:cloud_volume_openstack, :cloud_tenant => tenant, :status => 'available')
      record = FactoryGirl.create(:vm_openstack, :cloud_tenant => tenant)
      button = described_class.new(view_context, {}, {"record" => record}, {})
      expect(button.disabled?).to be false
    end

    it "when there are no available volumes then the button is disabled" do
      view_context = setup_view_context_with_sandbox({})
      tenant = FactoryGirl.create(:cloud_tenant_openstack)
      volume = FactoryGirl.create(:cloud_volume_openstack, :cloud_tenant => tenant, :status => 'in-use')
      record = FactoryGirl.create(:vm_openstack, :cloud_tenant => tenant)
      button = described_class.new(view_context, {}, {"record" => record}, {})
      expect(button.disabled?).to be true
    end
  end

  describe '#calculate_properties' do
    it "when there are no available volumes then the button has the error in the title" do
      view_context = setup_view_context_with_sandbox({})
      tenant = FactoryGirl.create(:cloud_tenant_openstack)
      volume = FactoryGirl.create(:cloud_volume_openstack, :cloud_tenant => tenant, :status => 'in-use')
      record = FactoryGirl.create(:vm_openstack, :cloud_tenant => tenant)
      button = described_class.new(view_context, {}, {"record" => record}, {})
      button.calculate_properties
      expect(button[:title]).to eq(_("There are no %{volumes} available to attach to this %{model}.") % {
        :model   => ui_lookup(:table => 'vm_cloud'),
        :volumes => ui_lookup(:tables => 'cloud_volumes')
      })
    end

    it "when there are available volumes, the button has no error in the title" do
      view_context = setup_view_context_with_sandbox({})
      tenant = FactoryGirl.create(:cloud_tenant_openstack)
      volume = FactoryGirl.create(:cloud_volume_openstack, :cloud_tenant => tenant, :status => 'available')
      record = FactoryGirl.create(:vm_openstack, :cloud_tenant => tenant)
      button = described_class.new(view_context, {}, {"record" => record}, {})
      button.calculate_properties
      expect(button[:title]).to be nil
    end
  end
end
