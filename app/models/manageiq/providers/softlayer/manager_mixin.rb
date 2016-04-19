module ManageIQ::Providers::SoftLayer::ManagerMixin
  extend ActiveSupport::Concern

  def connect(options = {})
    require 'fog/softlayer'

    raise MiqException::MiqHostError, "No credentials defined" if missing_credentials?(options[:auth_type])

    client_id = options[:user] || authentication_userid(options[:auth_type])
    client_key = options[:api_key] || authentication_key(options[:auth_type])

    self.class.raw_connect(client_id, client_key, options)
  end

  def verify_credentials(_auth_type = nil, options = {})
    connect(options)

    # Hit the SoftLayer servers to make sure authentication has
    # been procced
    connection.regions.all
  rescue Excon::Errors::Unauthorized => err
    raise MiqException::MiqInvalidCredentialsError, err.message

    true
  end

  module ClassMethods
    def raw_connect(softlayer_username, soflayer_api_key, options)
      require 'fog/softlayer'

      config = {
        :provider           => "softlayer",
        :softlayer_username => softlayer_username,
        :softlayer_api_key  => soflayer_api_key
      }

      case options[:service]
      when 'compute', nil
        ::Fog::Compute.new(config)
      when 'network'
        ::Fog::Network.new(config)
      when 'dns'
        ::Fog::DNS.new(config)
      when 'storage'
        ::Fog::Storage.new(config)
      when 'account'
        ::Fog::Account.new(config)
      else
        raise ArgumentError, "Unknown service: #{options[:service]}"
      end
    end

    # Discovery

    def discover(client_id, client_key)
    end

    def discover_queue(_client_id, _client_key)
      MiqQueue.put(
        :class_name  => name,
        :method_name => "discover_from_queue",
        :args        => [clientid, MiqPassword.encrypt(clientkey), azure_tenant_id, subscription]
      )
    end

    def vms_in_region(compute, region)
      compute.servers.all.select { |vm| vm.datacenter == region }
    end

    def discover_from_queue(client_id, client_key, azure_tenant_id, subscription)
    end

    def create_discovered_region(region_name, client_id, client_key)
    end
  end
end
