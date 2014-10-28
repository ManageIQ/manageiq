require "spec_helper"

$LOAD_PATH.push(File.expand_path(File.join(File.dirname(__FILE__), %w(.. .. .. openstack))))
require 'openstack_handle/handle'
require 'fog/openstack'

describe OpenstackHandle::Handle do
  before do
    @original_log = $fog_log
    $fog_log = double.as_null_object
  end

  after do
    $fog_log = @original_log
  end

  context "errors from services" do

    it "ignores 404 errors from services" do
      openstack_svc = double('newtork_service')
      expect(openstack_svc).to receive(:security_groups).and_raise(Fog::Network::OpenStack::NotFound)

      handle = OpenstackHandle::Handle.new("dummy", "dummy", "dummy")
      expect(handle).to receive(:service_for_each_accessible_tenant).and_yield(openstack_svc)

      data = handle.accessor_for_accessible_tenants("Network", :security_groups, :id)
      data.should be_empty
    end
  end

  context "supports ssl" do
    it "handles non-ssl connections just fine" do
      fog      = double('fog')
      handle   = OpenstackHandle::Handle.new("dummy", "dummy", "address")
      auth_url = OpenstackHandle::Handle.auth_url("address")

      OpenstackHandle::Handle.should_receive(:raw_connect).once do |_, _, address|
        address.should == auth_url
        fog
      end
      handle.connect(:tenant_name => "admin").should == fog
    end

    it "handles ssl connections just fine, too" do
      fog            = double('fog')
      handle         = OpenstackHandle::Handle.new("dummy", "dummy", "address")
      auth_url_nossl = OpenstackHandle::Handle.auth_url("address")
      auth_url_ssl   = OpenstackHandle::Handle.auth_url("address", 5000, true)

      # setup the socket error for the initial non-ssl failure
      socket_error = double('socket_error')
      allow(socket_error).to receive(:message).and_return("end of file reached (EOFError)")
      socket_error.should_receive(:class).and_return(Object)
      socket_error.should_receive(:backtrace)

      OpenstackHandle::Handle.should_receive(:raw_connect) do |_, _, address|
        address.should == auth_url_nossl
        raise Excon::Errors::SocketError.new(socket_error)
      end
      OpenstackHandle::Handle.should_receive(:raw_connect) do |_, _, address|
        address.should == auth_url_ssl
        fog
      end

      handle.connect(:tenant_name => "admin").should == fog
    end
  end
end
