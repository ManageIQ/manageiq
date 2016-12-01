class ManageIQ::Providers::Openstack::CloudManager < ManageIQ::Providers::CloudManager
  require_nested :AuthKeyPair
  require_nested :AvailabilityZone
  require_nested :AvailabilityZoneNull
  require_nested :CloudResourceQuota
  require_nested :CloudTenant
  require_nested :CloudVolume
  require_nested :CloudVolumeBackup
  require_nested :CloudVolumeSnapshot
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :Flavor
  require_nested :HostAggregate
  require_nested :MetricsCapture
  require_nested :MetricsCollectorWorker
  require_nested :OrchestrationServiceOptionConverter
  require_nested :OrchestrationStack
  require_nested :Provision
  require_nested :ProvisionWorkflow
  require_nested :Refresher
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Template
  require_nested :Vm

  has_many :storage_managers,
           :foreign_key => :parent_ems_id,
           :class_name  => "ManageIQ::Providers::StorageManager",
           :autosave    => true,
           :dependent   => :destroy

  include CinderManagerMixin
  include SwiftManagerMixin
  include ManageIQ::Providers::Openstack::ManagerMixin

  supports :provisioning
  supports :cloud_tenant_mapping do
    if defined?(self.class.parent::CloudManager::CloudTenant) && !tenant_mapping_enabled?
      unsupported_reason_add(:cloud_tenant_mapping, _("Tenant mapping is disabled on the Provider"))
    elsif !defined?(self.class.parent::CloudManager::CloudTenant)
      unsupported_reason_add(:cloud_tenant_mapping, _("Tenant mapping is supported only when CloudTenant exists "\
                                                      "on the CloudManager"))
    end
  end
  supports :cinder_service
  supports :swift_service
  supports :create_host_aggregate

  before_create :ensure_managers,
                    :ensure_cinder_managers,
                    :ensure_swift_managers

  def ensure_network_manager
    build_network_manager(:type => 'ManageIQ::Providers::Openstack::NetworkManager') unless network_manager
  end

  def ensure_cinder_manager
    return false if cinder_manager
    build_cinder_manager(:type => 'ManageIQ::Providers::StorageManager::CinderManager')
    true
  end

  def ensure_swift_manager
    return false if swift_manager
    build_swift_manager(:type => 'ManageIQ::Providers::StorageManager::SwiftManager')
    true
  end

  def supports_cloud_tenants?
    true
  end

  def cinder_service
    vs = openstack_handle.detect_volume_service
    vs.name == :cinder ? vs : nil
  end

  def swift_service
    vs = openstack_handle.detect_storage_service
    vs.name == :swift ? vs : nil
  end

  def self.ems_type
    @ems_type ||= "openstack".freeze
  end

  def self.description
    @description ||= "OpenStack".freeze
  end

  def self.default_blacklisted_event_names
    %w(
      identity.authenticate
      scheduler.run_instance.start
      scheduler.run_instance.scheduled
      scheduler.run_instance.end
    )
  end

  def hostname_uniqueness_valid?
    return unless hostname_required?
    return unless hostname.present? # Presence is checked elsewhere

    existing_providers = Endpoint.where(:hostname => hostname.downcase)
                                 .where.not(:resource_id => id).includes(:resource)
                                 .select do |endpoint|
                                   unless endpoint.resource.nil?
                                     endpoint.resource.uid_ems == keystone_v3_domain_id &&
                                       endpoint.resource.provider_region == provider_region
                                   end
                                 end

    errors.add(:hostname, "has already been taken") if existing_providers.any?
  end

  def supports_port?
    true
  end

  def supports_api_version?
    true
  end

  def supports_security_protocol?
    true
  end

  def supported_auth_types
    %w(default amqp)
  end

  def supports_provider_id?
    true
  end

  def supports_cinder_service?
    openstack_handle.detect_volume_service.name == :cinder
  end

  def supports_swift_service?
    openstack_handle.detect_storage_service.name == :swift
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
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

  def vm_pause(vm, _options = {})
    vm.pause
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_suspend(vm, _options = {})
    vm.suspend
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_shelve(vm, _options = {})
    vm.shelve
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_shelve_offload(vm, _options = {})
    vm.shelve_offload
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

  def vm_reset(vm, _options = {})
    vm.reset
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_create_snapshot(vm, options = {})
    log_prefix = "vm=[#{vm.name}]"

    miq_openstack_instance = MiqOpenStackInstance.new(vm.ems_ref, openstack_handle)
    snapshot = miq_openstack_instance.create_snapshot(options)
    snapshot_id = snapshot["id"]

    # Add new snapshot to the snapshots table.
    vm.snapshots.create!(
      :name        => options[:name],
      :description => options[:desc],
      :uid         => snapshot_id,
      :uid_ems     => snapshot_id,
      :ems_ref     => snapshot_id,
      :create_time => snapshot["created"]
    )

    return snapshot_id
  rescue => err
    _log.error "#{log_prefix}, error: #{err}"
    _log.debug { err.backtrace.join("\n") }
    raise
  end

  def vm_remove_snapshot(vm, options = {})
    snapshot_uid = options[:snMor]

    log_prefix = "snapshot=[#{snapshot_uid}]"

    miq_openstack_instance = MiqOpenStackInstance.new(vm.ems_ref, openstack_handle)
    miq_openstack_instance.delete_evm_snapshot(snapshot_uid)

    # Remove from the snapshots table.
    ar_snapshot = vm.snapshots.find_by(:ems_ref  => snapshot_uid)
    _log.debug "#{log_prefix}: ar_snapshot = #{ar_snapshot.class.name}"
    ar_snapshot.destroy if ar_snapshot

    # Remove from the vms table.
    ar_template = miq_templates.find_by(:ems_ref  => snapshot_uid)
    _log.debug "#{log_prefix}: ar_template = #{ar_template.class.name}"
    ar_template.destroy if ar_template
  rescue => err
    _log.error "#{log_prefix}, error: #{err}"
    _log.debug { err.backtrace.join("\n") }
    raise
  end

  def vm_remove_all_snapshots(vm, options = {})
    vm.snapshots.each { |snapshot| vm_remove_snapshot(vm, :snMor => snapshot.uid) }
  end

  # TODO: Should this be in a VM-specific subclass or mixin?
  #       This is a general EMS question.
  def vm_create_evm_snapshot(vm, options = {})
    require "OpenStackExtract/MiqOpenStackVm/MiqOpenStackInstance"

    log_prefix = "vm=[#{vm.name}]"

    miq_openstack_instance = MiqOpenStackInstance.new(vm.ems_ref, openstack_handle)
    miq_snapshot = miq_openstack_instance.create_evm_snapshot(options)

    # Add new snapshot image to the vms table. Type is TemplateOpenstack.
    miq_templates.create!(
      :type     => "ManageIQ::Providers::Openstack::CloudManager::Template",
      :vendor   => "openstack",
      :name     => miq_snapshot.name,
      :uid_ems  => miq_snapshot.id,
      :ems_ref  => miq_snapshot.id,
      :template => true,
      :location => "unknown"
    )

    # Add new snapshot to the snapshots table.
    vm.snapshots.create!(
      :name        => miq_snapshot.name,
      :description => options[:desc],
      :uid         => miq_snapshot.id,
      :uid_ems     => miq_snapshot.id,
      :ems_ref     => miq_snapshot.id
    )
    return miq_snapshot.id
  rescue => err
    _log.error "#{log_prefix}, error: #{err}"
    _log.debug { err.backtrace.join("\n") }
    raise
  end

  def vm_delete_evm_snapshot(vm, image_id)
    require "OpenStackExtract/MiqOpenStackVm/MiqOpenStackInstance"

    log_prefix = "snapshot=[#{image_id}]"

    miq_openstack_instance = MiqOpenStackInstance.new(vm.ems_ref, openstack_handle)
    miq_openstack_instance.delete_evm_snapshot(image_id)

    # Remove from the snapshots table.
    ar_snapshot = vm.snapshots.find_by(:ems_ref  => image_id)
    _log.debug "#{log_prefix}: ar_snapshot = #{ar_snapshot.class.name}"
    ar_snapshot.destroy if ar_snapshot

    # Remove from the vms table.
    ar_template = miq_templates.find_by(:ems_ref  => image_id)
    _log.debug "#{log_prefix}: ar_template = #{ar_template.class.name}"
    ar_template.destroy if ar_template
  rescue => err
    _log.error "#{log_prefix}, error: #{err}"
    _log.debug { err.backtrace.join("\n") }
    raise
  end

  def vm_attach_volume(vm, volume_id, device = nil)
    volume = find_by_id_filtered(CloudVolume, volume_id)
    volume.raw_attach_volume(vm.ems_ref, device)
  end

  def vm_detach_volume(vm, volume_id)
    volume = find_by_id_filtered(CloudVolume, volume_id)
    volume.raw_detach_volume(vm.ems_ref)
  end

  def create_host_aggregate(options)
    ManageIQ::Providers::Openstack::CloudManager::HostAggregate.create_aggregate(self, options)
  end

  def create_host_aggregate_queue(userid, options)
    ManageIQ::Providers::Openstack::CloudManager::HostAggregate.create_aggregate_queue(userid, self, options)
  end

  def self.event_monitor_class
    ManageIQ::Providers::Openstack::CloudManager::EventCatcher
  end

  #
  # Statistics
  #

  def block_storage_disk_usage
    cloud_volumes.where.not(:status => "error").sum(:size).to_f +
      cloud_volume_snapshots.where.not(:status => "error").sum(:size).to_f
  end

  def object_storage_disk_usage(swift_replicas = 1)
    cloud_object_store_containers.sum(:bytes).to_f * swift_replicas
  end
end
