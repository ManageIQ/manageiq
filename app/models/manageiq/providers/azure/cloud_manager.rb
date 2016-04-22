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

  include ManageIQ::Providers::Azure::ManagerMixin

  alias_attribute :azure_tenant_id, :uid_ems

  has_many :resource_groups, :foreign_key => :ems_id, :dependent => :destroy

  has_one :network_manager,
          :foreign_key => :parent_ems_id,
          :class_name  => "ManageIQ::Providers::Azure::NetworkManager",
          :autosave    => true,
          :dependent   => :destroy

  delegate :floating_ips,
           :security_groups,
           :cloud_networks,
           :cloud_subnets,
           :network_ports,
           :network_routers,
           :public_networks,
           :private_networks,
           :all_cloud_networks,
           :to        => :network_manager,
           :allow_nil => true

  before_validation :ensure_managers

  def ensure_managers
    build_network_manager unless network_manager
    network_manager.name            = "#{name} Network Manager"
    network_manager.zone_id         = zone_id
    network_manager.provider_region = provider_region
  end

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

  def vm_suspend(vm, _options = {})
    vm.suspend
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
end
