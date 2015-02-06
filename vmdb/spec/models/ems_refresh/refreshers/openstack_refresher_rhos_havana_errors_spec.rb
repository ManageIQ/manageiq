require "spec_helper"

describe EmsRefresh::Refreshers::OpenstackRefresher do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(
      :ems_openstack,
      :zone      => zone,
      :hostname  => "1.2.3.4",
      :ipaddress => "1.2.3.4",
      :port      => 5000)
    @ems.update_authentication(:default => {:userid => "admin", :password => "password"})
  end

  it "will record an error when trying to perform a full refresh against RHOS Havana" do
    error = "Bad Request"
    refresh_ems(@ems, error)
    assert_failed_refresh(error)
  end

  def assert_failed_refresh(error)
    @ems.last_refresh_status.should == "error"
    @ems.last_refresh_error.should == error
  end

  def refresh_ems(ems, error)
    EmsRefresh::Parsers::Openstack.stub(:ems_inv_to_hashes).and_raise(Excon::Errors::BadRequest.new(error))
    EmsRefresh.refresh(ems)
  end
end
