class ManageIQ::Providers::SoftLayer::CloudManager < ManageIQ::Providers::CloudManager
  require_nested :AvailabilityZone
  require_nested :Flavor
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :Vm
  require_nested :Template
  require_nested :Provision
  require_nested :ProvisionWorkflow

  include ManageIQ::Providers::SoftLayer::ManagerMixin

  has_one :network_manager,
          :foreign_key => :parent_ems_id,
          :class_name  => "ManageIQ::Providers::SoftLayer::NetworkManager",
          :autosave    => true,
          :dependent   => :destroy

  delegate :floating_ips, # not sure
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

  ExtManagementSystem.register_cloud_discovery_type('soft_layer' => 'soft_layer')

  def self.ems_type
    @ems_type ||= "soft_layer".freeze
  end

  def self.description
    @description ||= "SoftLayer".freeze
  end

  def self.hostname_required?
    false
  end

  def description
    ManageIQ::Providers::SoftLayer::Regions.find_by_name(provider_region)[:description]
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
    vm.destroy
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_reboot(vm, _options = {})
    vm.reboot
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end
end
