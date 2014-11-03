require "spec_helper"

describe MiqVimBrokerWorker do
  before(:each) do
    guid, server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_vmware_with_authentication, :zone => @zone)
    other_ems = FactoryGirl.create(:ems_vmware_with_authentication, :zone => @zone)

    # General stubbing for testing any worker (methods called during initialize)
    EmsVmware.any_instance.stub(:authentication_check).and_return(true)
  end

  it ".emses_to_monitor" do
    described_class.emses_to_monitor.should match_array @zone.ext_management_systems
  end

end
