require "spec_helper"

describe MiqVimBrokerWorker do
  before(:each) do
    guid, server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_vmware_with_authentication, :zone => @zone)
    other_ems = FactoryGirl.create(:ems_vmware_with_authentication, :zone => @zone)
    allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive_messages(:authentication_status_ok? => true)
  end

  it ".emses_to_monitor" do
    expect(described_class.emses_to_monitor).to match_array @zone.ext_management_systems
  end
end
