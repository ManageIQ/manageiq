module ManageIQ::Providers::Azure::ManagerMixin
  extend ActiveSupport::Concern

  def connect(options = {})
    raise MiqException::MiqHostError, _("No credentials defined") if missing_credentials?(options[:auth_type])

    client_id  = options[:user] || authentication_userid(options[:auth_type])
    client_key = options[:pass] || authentication_password(options[:auth_type])
    self.class.raw_connect(client_id, client_key, azure_tenant_id, subscription, options[:proxy_uri] || http_proxy_uri, provider_region)
  end

  def verify_credentials(_auth_type = nil, options = {})
    require 'azure-armrest'
    conf = connect(options)
  rescue ArgumentError => err
    raise MiqException::MiqInvalidCredentialsError, _("Incorrect credentials - #{err.message}")
  rescue ::Azure::Armrest::UnauthorizedException, ::Azure::Armrest::BadRequestException
    raise MiqException::MiqInvalidCredentialsError, _("Incorrect credentials - check your Azure Client ID and Client Key")
  rescue MiqException::MiqInvalidCredentialsError
    raise # Raise before falling into catch-all block below
  rescue StandardError => err
    _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
    raise MiqException::MiqInvalidCredentialsError, _("Unexpected response returned from system: #{err.message}")
  else
    conf
  end

  module ClassMethods
    def raw_connect(client_id, client_key, azure_tenant_id, subscription, proxy_uri = nil, provider_region = nil)

      require 'azure-armrest'

      if subscription.blank?
        raise MiqException::MiqInvalidCredentialsError, _("Incorrect credentials - check your Azure Subscription ID")
      end

      ::Azure::Armrest::ArmrestService.configure(
        :client_id       => client_id,
        :client_key      => client_key,
        :tenant_id       => azure_tenant_id,
        :subscription_id => subscription,
        :proxy           => proxy_uri,
        :environment     => environment_for(provider_region)
      )
    end

    def environment_for(region)
      case region
      when /usgov/i
        ::Azure::Armrest::Environment::USGovernment
      else
        ::Azure::Armrest::Environment::Public
      end
    end

    # Discovery

    # Create EmsAzure instances for all regions with instances
    # or images for the given authentication. Created EmsAzure instances
    # will automatically have EmsRefreshes queued up.  If this is a greenfield
    # discovery, we will at least add an EmsAzure for eastus
    def discover(clientid, clientkey, azure_tenant_id, subscription)
      new_emses = []

      all_emses = includes(:authentications)
      all_ems_names = all_emses.index_by(&:name)

      known_emses = all_emses.select { |e| e.authentication_userid == clientid }
      known_ems_regions = known_emses.index_by(&:provider_region)

      config     = raw_connect(clientid, clientkey, azure_tenant_id, subscription)
      azure_vmm  = ::Azure::Armrest::VirtualMachineService.new(config)

      azure_vmm.locations.each do |region|
        region = region.delete(' ').downcase
        next if known_ems_regions.include?(region)
        next if vms_in_region(azure_vmm, region).count == 0 # instances
        # TODO: Check if images are == 0 and if so then skip
        new_emses << create_discovered_region(region, clientid, clientkey, azure_tenant_id, subscription, all_ems_names)
      end

      # at least create the Azure-eastus region.
      if new_emses.blank? && known_emses.blank?
        new_emses << create_discovered_region("eastus", clientid, clientkey, azure_tenant_id, subscription, all_ems_names)
      end

      EmsRefresh.queue_refresh(new_emses) unless new_emses.blank?

      new_emses
    end

    def discover_queue(clientid, clientkey, azure_tenant_id, subscription)
      MiqQueue.put(
        :class_name  => name,
        :method_name => "discover_from_queue",
        :args        => [clientid, MiqPassword.encrypt(clientkey), azure_tenant_id, subscription]
      )
    end

    def vms_in_region(azure_vmm, region)
      azure_vmm.list_all.select { |vm| vm['location'] == region }
    end

    def discover_from_queue(clientid, clientkey, azure_tenant_id, subscription)
      discover(clientid, MiqPassword.decrypt(clientkey), azure_tenant_id, subscription)
    end

    def create_discovered_region(region_name, clientid, clientkey, azure_tenant_id, subscription, all_ems_names)
      name = "Azure-#{region_name}"
      name = "Azure-#{region_name} #{clientid}" if all_ems_names.key?(name)

      while all_ems_names.key?(name)
        name_counter = name_counter.to_i + 1 if defined?(name_counter)
        name = "Azure-#{region_name} #{name_counter}"
      end

      new_ems = create!(
        :name            => name,
        :provider_region => region_name,
        :zone            => Zone.default_zone,
        :uid_ems         => azure_tenant_id,
        :subscription    => subscription
      )
      new_ems.update_authentication(
        :default => {
          :userid   => clientid,
          :password => clientkey
        }
      )
      new_ems
    end
  end
end
