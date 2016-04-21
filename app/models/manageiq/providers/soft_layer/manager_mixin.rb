module ManageIQ::Providers::SoftLayer::ManagerMixin
  extend ActiveSupport::Concern

  def connect(options = {})
    raise MiqException::MiqHostError, "No credentials defined" if missing_credentials?(options[:auth_type])

    client_id = options[:client_id] || authentication_userid(options[:auth_type])
    client_key = options[:client_key] || authentication_key(options[:auth_type])

    self.class.raw_connect(client_id, client_key, options)
  end

  def verify_credentials(_auth_type = nil, options = {})
    connect(options)

    # Hit the SoftLayer servers to make sure authentication has
    # been proceed
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

    # Process each region, add it as a new provider and queue refresh
    def discover(client_id, client_key)
      new_ems = []

      all_ems = includes(:authentications)
      all_ems_names = all_ems.index_by(&:name)

      known_ems = all_ems.select { |e| e.authentication_userid == client_id }
      known_ems_regions = known_ems.index_by(&:provider_region)

      compute = raw_connect(client_id, client_key)
      network = raw_connect(client_id, client_key, :service => "network")

      network.datacenters.each do |region|
        next if known_ems_regions.include?(region.name)
        next if servers_in_region(compute, region.name).empty?

        new_ems << create_discovered_region(region, client_id, client_key, all_ems_names)
      end

      EmsRefresh.queue_refresh(new_ems) unless new_ems.blank?

      new_ems
    end

    def discover_queue(client_id, client_key)
      MiqQueue.put(
        :class_name  => name,
        :method_name => "discover_from_queue",
        :args        => [client_id, MiqPassword.encrypt(client_key)]
      )
    end

    def servers_in_region(compute, region)
      compute.servers.all.select { |vm| vm.datacenter == region }
    end

    def discover_from_queue(client_id, client_key)
      discover(client_id, MiqPassword.decrypt(client_key))
    end

    def create_discovered_region(region_name, client_id, client_key, all_ems_names)
      # TODO: Why is there all this sting gymnastics? Is it really needed?
      name = "SoftLayer-#{region_name}"
      name = "SoftLayer-#{region_name} #{clientid}" if all_ems_names.key?(name)

      while all_ems_names.key?(name)
        name_counter = name_counter.to_i + 1 if defined?(name_counter)
        name = "SoftLayer-#{region_name} #{name_counter}"
      end

      # TODO: Is the uid_ems really needed here?
      new_ems = create!(
        :name            => name,
        :provider_region => region_name,
        :zone            => Zone.default_zone
      )
      new_ems.update_authentication(
        :default => {
          :userid   => client_id,
          :password => client_key
        }
      )
      new_ems
    end
  end
end
