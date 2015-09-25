require "spec_helper"

describe ManageIQ::Providers::Vmware::InfraManager::Refresher do
  before(:each) do
    EmsRefresh.debug_failures = false

    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(
      :ems_vmware,
      :zone      => zone,
      :hostname  => "1.2.3.4",
      :ipaddress => "1.2.3.4",
      :port      => 5000)
    @ems.update_authentication(:default => {:userid => "admin", :password => "password"})
  end

  it "will record an error when trying to perform a full refresh against Vmware" do
    error = "Error getting VC data"
    refresh_ems(@ems, error)
    assert_failed_refresh(error)
  end

  def assert_failed_refresh(error)
    @ems.last_refresh_status.should == "error"
    @ems.last_refresh_error.should == error
  end

  def refresh_ems(ems, error)
    ManageIQ::Providers::Vmware::InfraManager::Refresher.any_instance.stub(:refresh_targets_for_ems).and_raise(StandardError.new(error))
    EmsRefresh.refresh(ems)
  end
end
