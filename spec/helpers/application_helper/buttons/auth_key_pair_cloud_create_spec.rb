describe ApplicationHelper::Button::AuthKeyPairCloudCreate do
  describe '#disabled?' do
    it "when the create action is available then the button is not disabled" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(view_context, {}, {}, {})
      ems = object_double(ManageIQ::Providers::CloudManager.new, :class => ManageIQ::Providers::Openstack::CloudManager)
      allow(ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair).to receive(:is_available?).and_return(true)
      allow(Rbac).to receive(:filtered).and_return([ems])
      expect(button.disabled?).to be false
    end

    it "when the create action is unavailable then the button is disabled" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(view_context, {}, {}, {})
      ems = object_double(ManageIQ::Providers::CloudManager.new, :class => ManageIQ::Providers::Openstack::CloudManager)
      allow(ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair).to receive(:is_available?).and_return(false)
      allow(Rbac).to receive(:filtered).and_return([ems])
      expect(button.disabled?).to be true
    end
  end

  describe '#calculate_properties' do
    it "when the create action is unavailable the button has the error in the title" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(view_context, {}, {}, {})
      ems = object_double(ManageIQ::Providers::CloudManager.new, :class => ManageIQ::Providers::Openstack::CloudManager)
      allow(ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair).to receive(:is_available?).and_return(false)
      allow(Rbac).to receive(:filtered).and_return([ems])
      button.calculate_properties
      expect(button[:title]).to eq("No cloud providers support key pair import or creation.")
    end

    it "when the create action is available, the button has no error in the title" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(view_context, {}, {}, {})
      ems = object_double(ManageIQ::Providers::CloudManager.new, :class => ManageIQ::Providers::Openstack::CloudManager)
      allow(ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair).to receive(:is_available?).and_return(true)
      allow(Rbac).to receive(:filtered).and_return([ems])
      button.calculate_properties
      expect(button[:title]).to be nil
    end
  end
end
