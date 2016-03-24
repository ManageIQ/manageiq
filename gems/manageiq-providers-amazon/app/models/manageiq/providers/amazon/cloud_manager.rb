class ManageIQ::Providers::Amazon::CloudManager < ManageIQ::Providers::CloudManager
  require_nested :AuthKeyPair
  require_nested :AvailabilityZone
  require_nested :CloudVolume
  require_nested :CloudVolumeSnapshot
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :MetricsCapture
  require_nested :MetricsCollectorWorker
  require_nested :OrchestrationServiceOptionConverter
  require_nested :OrchestrationStack
  require_nested :Provision
  require_nested :ProvisionWorkflow
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :Template
  require_nested :Vm

  OrchestrationTemplateCfn.register_eligible_manager(self)
  ExtManagementSystem.register_cloud_discovery_type('amazon' => 'ec2')

  include ManageIQ::Providers::Amazon::ManagerMixin

  has_one :network_manager,
          :foreign_key => :parent_ems_id,
          :class_name  => "ManageIQ::Providers::Amazon::NetworkManager",
          :autosave    => true

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

  def self.ems_type
    @ems_type ||= "ec2".freeze
  end

  def self.description
    @description ||= "Amazon EC2".freeze
  end

  def self.hostname_required?
    false
  end

  def self.default_blacklisted_event_names
    %w(
      ConfigurationSnapshotDeliveryCompleted
      ConfigurationSnapshotDeliveryStarted
      ConfigurationSnapshotDeliveryFailed
    )
  end

  #
  # Operations
  #

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

  def vm_reboot_guest(vm, _options = {})
    vm.reboot_guest
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  # @param [OrchestrationTemplateCfn] template
  # @return [nil] if the template is valid
  # @return [String] if the template is invalid this is the error message
  def orchestration_template_validate(template)
    with_provider_connection(:service => :CloudFormation) do |cloud_formation|
      nil if cloud_formation.client.validate_template(:template_body => template.content)
    end
  rescue Aws::CloudFormation::Errors::ValidationError => validation_error
    validation_error.message
  rescue => err
    _log.error "template=[#{template.name}], error: #{err}"
    raise MiqException::MiqOrchestrationValidationError, err.to_s, err.backtrace
  end
end
