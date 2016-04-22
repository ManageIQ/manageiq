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

  it ".url" do
    expect(described_class.url("::1")).to eq "http://[::1]:5000"
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
    it "handles default ssl type connections just fine" do
      fog      = double('fog')
      handle   = OpenstackHandle::Handle.new("dummy", "dummy", "address")
      auth_url = OpenstackHandle::Handle.auth_url("address", 5000, "https")

      expect(OpenstackHandle::Handle).to receive(:raw_connect).with(
                                           "dummy",
                                           "dummy",
                                           "https://address:5000/v2.0/tokens",
                                           "Compute",
                                           {:openstack_tenant       => "admin",
                                            :openstack_project_name => "admin",
                                            :openstack_domain_id    => nil,
                                            :connection_options     => {:ssl_verify_peer => false}})
                                           .once do |_, _, address|
        expect(address).to eq(auth_url)
        fog
      end
      expect(handle.connect(:tenant_name => "admin")).to eq(fog)
    end

    it "handles non ssl connections just fine" do
      fog      = double('fog')
      handle   = OpenstackHandle::Handle.new("dummy", "dummy", "address", 5000, 'v2', 'non-ssl')
      auth_url = OpenstackHandle::Handle.auth_url("address", 5000, "http")

      expect(OpenstackHandle::Handle).to receive(:raw_connect).with(
                                           "dummy",
                                           "dummy",
                                           "http://address:5000/v2.0/tokens",
                                           "Compute",
                                           {:openstack_tenant       => "admin",
                                            :openstack_project_name => "admin",
                                            :openstack_domain_id    => nil,
                                            :connection_options     => {}})
                                           .once do |_, _, address|
        expect(address).to eq(auth_url)
        fog
      end
      expect(handle.connect(:tenant_name => "admin")).to eq(fog)
    end

    it "handles ssl connections just fine, too" do
      fog            = double('fog')
      handle         = OpenstackHandle::Handle.new("dummy", "dummy", "address", 5000, 'v2', 'ssl')
      auth_url_ssl   = OpenstackHandle::Handle.auth_url("address", 5000, "https")

      expect(OpenstackHandle::Handle).to receive(:raw_connect).with(
                                           "dummy",
                                           "dummy",
                                           "https://address:5000/v2.0/tokens",
                                           "Compute",
                                           {:openstack_tenant       => "admin",
                                            :openstack_project_name => "admin",
                                            :openstack_domain_id    => nil,
                                            :connection_options     => {:ssl_verify_peer => false}}) do |_, _, address|
        expect(address).to eq(auth_url_ssl)
        fog
      end

      expect(handle.connect(:tenant_name => "admin")).to eq(fog)
    end

    it "handles ssl with validation connections just fine, too" do
      fog            = double('fog')
      handle         = OpenstackHandle::Handle.new("dummy", "dummy", "address", 5000, 'v2', 'ssl-with-validation')
      auth_url_ssl   = OpenstackHandle::Handle.auth_url("address", 5000, "https")

      expect(OpenstackHandle::Handle).to receive(:raw_connect).with(
                                           "dummy",
                                           "dummy",
                                           "https://address:5000/v2.0/tokens",
                                           "Compute",
                                           {:openstack_tenant       => "admin",
                                            :openstack_project_name => "admin",
                                            :openstack_domain_id    => nil,
                                            :connection_options     => {:ssl_verify_peer => true}}) do |_, _, address|
        expect(address).to eq(auth_url_ssl)
        fog
      end

      expect(handle.connect(:tenant_name => "admin")).to eq(fog)
    end

    it "handles ssl passing of extra params validation connections just fine, too" do
      fog            = double('fog')
      extra_options  = {
        :ssl_ca_file    => "file",
        :ssl_ca_path    => "path",
        :ssl_cert_store => "store_obj"
      }

      expected_options = {:openstack_tenant       => "admin",
                          :openstack_project_name => "admin",
                          :openstack_domain_id    => nil,
                          :connection_options     => {:ssl_verify_peer => true,
                                                      :ssl_ca_file     => "file",
                                                      :ssl_ca_path     => "path",
                                                      :ssl_cert_store  => "store_obj"}}

      handle           = OpenstackHandle::Handle.new("dummy", "dummy", "address", 5000, 'v2', 'ssl-with-validation', extra_options)
      auth_url_ssl     = OpenstackHandle::Handle.auth_url("address", 5000, "https")

      expect(OpenstackHandle::Handle).to receive(:raw_connect).with(
                                           "dummy",
                                           "dummy",
                                           "https://address:5000/v2.0/tokens",
                                           "Compute",
                                           expected_options
                                           ) do |_, _, address|
        expect(address).to eq(auth_url_ssl)
        fog
      end

      expect(handle.connect(:tenant_name => "admin")).to eq(fog)
    end
  end
end
