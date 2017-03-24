module Openstack
  module RefreshSpecHelpers
    def compute_data
      @compute_data ||= Openstack::Services::Compute::Data.new
    end

    def identity_data
      @identity_data ||= case identity_service
                         when :v3
                           Openstack::Services::Identity::Data::KeystoneV3.new
                         when :v2
                           Openstack::Services::Identity::Data::KeystoneV2.new
                         end
    end

    def image_data
      @image_data ||= Openstack::Services::Image::Data.new
    end

    def orchestration_data
      @orchestration_data ||= Openstack::Services::Orchestration::Data.new
    end

    def network_data
      @network_data ||= case networking_service
                        when :nova
                          Openstack::Services::Network::Data::Nova.new
                        when :neutron
                          Openstack::Services::Network::Data::Neutron.new
                        end
    end

    def volume_data
      @volume_data ||= Openstack::Services::Volume::Data.new
    end

    def storage_data
      @storage_data ||= Openstack::Services::Storage::Data.new
    end

    def with_cassette(version, ems)
      ems.reload
      # Caching OpenStack info between runs causes the tests to fail with:
      #   VCR::Errors::UnusedHTTPInteractionError
      # Reset the cache so HTTP interactions are the same between runs.
      ems.reset_openstack_handle

      # We need VCR to match requests differently here because fog adds a dynamic
      #   query param to avoid HTTP caching - ignore_awful_caching##########
      #   https://github.com/fog/fog/blob/master/lib/fog/openstack/compute.rb#L308
      VCR.use_cassette("#{described_class.name.underscore}_rhos_#{version}",
                       :match_requests_on => [:method, :host, :path, :query]) do
        # clear Fog's version cache before running the tests with the cassette,
        # otherwise it will not call the version API in subsequent runs
        Fog::OpenStack.instance_variable_set(:@version, nil)
        yield
      end
      ems.reload
    end

    def setup_ems(hostname, password, port = 5000, userid = "admin", version = "v2", keystone_v3_domain_id = nil)
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack,
                                :zone                   => zone,
                                :tenant_mapping_enabled => true,
                                :hostname               => hostname,
                                :ipaddress              => hostname,
                                :port                   => port,
                                :api_version            => version,
                                :security_protocol      => 'no_ssl',
                                :keystone_v3_domain_id  => keystone_v3_domain_id)
      @ems.update_authentication(:default => {:userid => userid, :password => password})
    end
  end
end
