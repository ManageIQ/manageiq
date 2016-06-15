describe MiqVimBrokerWorker do
  it ".emses_to_monitor" do
    _guid, _server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryGirl.create(:ems_vmware_with_authentication, :zone => @zone)
    FactoryGirl.create(:ems_vmware_with_authentication, :zone => @zone)
    allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive_messages(:authentication_status_ok? => true)

    expect(described_class.emses_to_monitor).to match_array @zone.ext_management_systems
  end
end
