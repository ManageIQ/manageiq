class ManageIQ::Providers::Openstack::CloudManager < EmsCloud
  require_dependency 'manageiq/providers/openstack/cloud_manager/auth_key_pair'
  require_dependency 'manageiq/providers/openstack/cloud_manager/availability_zone'
  require_dependency 'manageiq/providers/openstack/cloud_manager/availability_zone_null'
  require_dependency 'manageiq/providers/openstack/cloud_manager/cloud_resource_quota'
  require_dependency 'manageiq/providers/openstack/cloud_manager/cloud_tenant'
  require_dependency 'manageiq/providers/openstack/cloud_manager/cloud_volume'
  require_dependency 'manageiq/providers/openstack/cloud_manager/cloud_volume_snapshot'
  require_dependency 'manageiq/providers/openstack/cloud_manager/event_catcher'
  require_dependency 'manageiq/providers/openstack/cloud_manager/event_parser'
  require_dependency 'manageiq/providers/openstack/cloud_manager/flavor'
  require_dependency 'manageiq/providers/openstack/cloud_manager/floating_ip'
  require_dependency 'manageiq/providers/openstack/cloud_manager/metrics_collector_worker'
  require_dependency 'manageiq/providers/openstack/cloud_manager/orchestration_service_option_converter'
  require_dependency 'manageiq/providers/openstack/cloud_manager/orchestration_stack'
  require_dependency 'manageiq/providers/openstack/cloud_manager/provision'
  require_dependency 'manageiq/providers/openstack/cloud_manager/provision_workflow'
  require_dependency 'manageiq/providers/openstack/cloud_manager/refresher'
  require_dependency 'manageiq/providers/openstack/cloud_manager/refresh_parser'
  require_dependency 'manageiq/providers/openstack/cloud_manager/refresh_worker'
  require_dependency 'manageiq/providers/openstack/cloud_manager/security_group'
  require_dependency 'manageiq/providers/openstack/cloud_manager/template'
  require_dependency 'manageiq/providers/openstack/cloud_manager/vm'

  include ManageIQ::Providers::Openstack::ManagerMixin

  def self.ems_type
    @ems_type ||= "openstack".freeze
  end

  def self.description
    @description ||= "OpenStack".freeze
  end

  def supports_port?
    true
  end

  def supported_auth_types
    %w(default amqp)
  end

  def supports_provider_id?
    true
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  #
  # Operations
  #

  def vm_start(vm, options = {})
    vm.start
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_stop(vm, options = {})
    vm.stop
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_pause(vm, options = {})
    vm.pause
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_suspend(vm, options = {})
    vm.suspend
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_destroy(vm, options = {})
    vm.vm_destroy
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_reboot_guest(vm, options = {})
    vm.reboot_guest
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_reset(vm, options = {})
    vm.reset
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
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
    ar_snapshot = vm.snapshots.where(:ems_ref  => image_id).first
    _log.debug "#{log_prefix}: ar_snapshot = #{ar_snapshot.class.name}"
    ar_snapshot.destroy if ar_snapshot

    # Remove from the vms table.
    ar_template = miq_templates.where(:ems_ref  => image_id).first
    _log.debug "#{log_prefix}: ar_template = #{ar_template.class.name}"
    ar_template.destroy if ar_template
  rescue => err
    _log.error "#{log_prefix}, error: #{err}"
    _log.debug { err.backtrace.join("\n") }
    raise
  end

  def self.event_monitor_class
    ManageIQ::Providers::Openstack::CloudManager::EventCatcher
  end
end
