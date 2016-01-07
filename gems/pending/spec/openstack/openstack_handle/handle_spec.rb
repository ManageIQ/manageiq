require "spec_helper"
require 'openstack/openstack_handle/handle'
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
    before do
      @openstack_svc = double('network_service')
      @openstack_project = double('project')

      @handle = OpenstackHandle::Handle.new("dummy", "dummy", "dummy")
      allow(@handle).to receive(:service_for_each_accessible_tenant).and_yield(@openstack_svc, @openstack_project)
    end

    it "ignores 404 errors from services" do
      expect(@openstack_svc).to receive(:security_groups).and_raise(Fog::Network::OpenStack::NotFound)

      data = @handle.accessor_for_accessible_tenants("Network", :security_groups, :id)
      expect(data).to be_empty
    end

    it "ignores 404 errors from services returning arrays" do
      security_groups = double("security_groups").as_null_object
      expect(security_groups).to receive(:to_a).and_raise(Fog::Network::OpenStack::NotFound)

      expect(@openstack_svc).to receive(:security_groups).and_return(security_groups)

      data = @handle.accessor_for_accessible_tenants("Network", :security_groups, :id)
      expect(data).to be_empty
    end
  end

  context "supports ssl" do
    it "handles non-ssl connections just fine" do
      fog      = double('fog')
      handle   = OpenstackHandle::Handle.new("dummy", "dummy", "address")
      auth_url = OpenstackHandle::Handle.auth_url("address", 5000, "https")

      expect(OpenstackHandle::Handle).to receive(:raw_connect).once do |_, _, address|
        expect(address).to eq(auth_url)
        fog
      end
      expect(handle.connect(:tenant_name => "admin")).to eq(fog)
    end

    it "handles ssl connections just fine, too" do
      fog            = double('fog')
      handle         = OpenstackHandle::Handle.new("dummy", "dummy", "address")
      auth_url_nossl = OpenstackHandle::Handle.auth_url("address")
      auth_url_ssl   = OpenstackHandle::Handle.auth_url("address", 5000, "https")

      # setup the socket error for the initial ssl failure
      socket_error = double('socket_error')
      allow(socket_error).to receive(:message).and_return("unknown protocol (OpenSSL::SSL::SSLError)")
      expect(socket_error).to receive(:class).and_return(Object)
      expect(socket_error).to receive(:backtrace)

      expect(OpenstackHandle::Handle).to receive(:raw_connect) do |_, _, address|
        expect(address).to eq(auth_url_ssl)
        raise Excon::Errors::SocketError.new(socket_error)
      end
      expect(OpenstackHandle::Handle).to receive(:raw_connect) do |_, _, address|
        expect(address).to eq(auth_url_nossl)
        fog
      end

      expect(handle.connect(:tenant_name => "admin")).to eq(fog)
    end
  end
end
