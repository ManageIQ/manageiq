describe MiqVimBrokerWorker do
  it ".emses_to_monitor" do
    _guid, _server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryGirl.create(:ems_vmware_with_authentication, :zone => @zone)
    FactoryGirl.create(:ems_vmware_with_authentication, :zone => @zone)
    allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive_messages(:authentication_status_ok? => true)

    expect(described_class.emses_to_monitor).to match_array @zone.ext_management_systems
  end

  context "update_driven_refresh" do
    before do
      stub_settings_merge(
        :prototype => {
          :ems_vmware => {
            :update_driven_refresh => true
          }
        }
      )
    end

    it ".required_roles" do
      expect(described_class.required_roles.call).not_to include('ems_inventory')
    end
  end

  context "standard refresh" do
    before do
      stub_settings_merge(
        :prototype => {
          :ems_vmware => {
            :update_driven_refresh => false
          }
        }
      )
    end

    it ".required_roles" do
      expect(described_class.required_roles.call).to include('ems_inventory')
    end
  end
end
