class ManageIQ::Providers::Azure::CloudManager < ManageIQ::Providers::CloudManager
  require_nested :AvailabilityZone
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :Flavor
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :Vm
  require_nested :Template
  require_nested :Provision
  require_nested :ProvisionWorkflow
  require_nested :OrchestrationStack
  require_nested :OrchestrationServiceOptionConverter
  require_nested :SecurityGroup

  alias_attribute :azure_tenant_id, :uid_ems

  has_many :resource_groups, :foreign_key => :ems_id, :dependent => :destroy

  ExtManagementSystem.register_cloud_discovery_type('azure' => 'azure')

  def self.ems_type
    @ems_type ||= "azure".freeze
  end

  def self.description
    @description ||= "Azure".freeze
  end

  def self.default_blacklisted_event_names
    %w(
      storageAccounts_listKeys_BeginRequest
      storageAccounts_listKeys_EndRequest
    )
  end

  def self.hostname_required?
    false
  end

  def description
    ManageIQ::Providers::Azure::Regions.find_by_name(provider_region)[:description]
  end

  def self.raw_connect(client_id, client_key, azure_tenant_id, proxy_uri = nil)
    proxy_uri ||= VMDB::Util.http_proxy_uri

    ::Azure::Armrest::ArmrestService.configure(
      :client_id  => client_id,
      :client_key => client_key,
      :tenant_id  => azure_tenant_id,
      :proxy      => proxy_uri.to_s
    )
  end

  def connect(options = {})
    raise MiqException::MiqHostError, _("No credentials defined") if missing_credentials?(options[:auth_type])

    client_id  = options[:user] || authentication_userid(options[:auth_type])
    client_key = options[:pass] || authentication_password(options[:auth_type])
    self.class.raw_connect(client_id, client_key, azure_tenant_id, options[:proxy_uri])
  end

  def verify_credentials(_auth_type = nil, options = {})
    connect(options)
  rescue Azure::Armrest::UnauthorizedException
    raise MiqException::MiqHostError, _("Incorrect credentials - check your Azure Client ID and Client Key")
  rescue StandardError => err
    _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
    raise MiqException::MiqHostError, _("Unexpected response returned from system, see log for details")

    true
  end

  # Operations

  def vm_start(vm, _options = {})
    vm.start
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_stop(vm, _options = {})
    vm.stop
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_destroy(vm, _options = {})
    vm.vm_destroy
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_restart(vm, _options = {})
    # TODO switch to vm.restart
    vm.raw_restart
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  # Discovery

  # Create EmsAzure instances for all regions with instances
  # or images for the given authentication.  Created EmsAzure instances
  # will automatically have EmsRefreshes queued up.  If this is a greenfield
  # discovery, we will at least add an EmsAzure for eastus
  def self.discover(clientid, clientkey, azure_tenant_id)
    new_emses = []

    all_emses = includes(:authentications)
    all_ems_names = all_emses.index_by(&:name)

    known_emses = all_emses.select { |e| e.authentication_userid == clientid }
    known_ems_regions = known_emses.index_by(&:provider_region)

    config     = raw_connect(clientid, clientkey, azure_tenant_id)
    azure_vmm  = ::Azure::Armrest::VirtualMachineService.new(config)

    azure_vmm.locations.each do |region|
      region = region.delete(' ').downcase
      next if known_ems_regions.include?(region)
      next if vms_in_region(azure_vmm, region).count == 0 # instances
      # TODO: Check if images are == 0 and if so then skip
      new_emses << create_discovered_region(region, clientid, clientkey, azure_tenant_id, all_ems_names)
    end

    # at least create the Azure-eastus region.
    if new_emses.blank? && known_emses.blank?
      new_emses << create_discovered_region("Azure-eastus", clientid, clientkey, azure_tenant_id, all_ems_names)
    end

    EmsRefresh.queue_refresh(new_emses) unless new_emses.blank?

    new_emses
  end

  def self.discover_queue(clientid, clientkey, azure_tenant_id)
    MiqQueue.put(
      :class_name  => name,
      :method_name => "discover_from_queue",
      :args        => [clientid, MiqPassword.encrypt(clientkey), azure_tenant_id]
    )
  end

  def self.vms_in_region(azure_vmm, region)
    azure_vmm.list_all.select { |vm| vm['location'] == region }
  end

  def self.discover_from_queue(clientid, clientkey, azure_tenant_id)
    discover(clientid, MiqPassword.decrypt(clientkey), azure_tenant_id)
  end

  def self.create_discovered_region(region_name, clientid, clientkey, azure_tenant_id, all_ems_names)
    name = "Azure-#{region_name}"
    name = "Azure-#{region_name} #{clientid}" if all_ems_names.key?(name)

    while all_ems_names.key?(name)
      name_counter = name_counter.to_i + 1 if defined?(name_counter)
      name = "Azure-#{region_name} #{name_counter}"
    end

    new_ems = self.create!(
      :name            => name,
      :provider_region => region_name,
      :zone            => Zone.default_zone,
      :uid_ems         => azure_tenant_id
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
