class EmsOpenstack < EmsCloud
  include EmsOpenstackMixin

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

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  #
  # Operations
  #

  def vm_start(vm, options = {})
    vm.start
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_pause(vm, options = {})
    vm.pause
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_suspend(vm, options = {})
    vm.suspend
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_destroy(vm, options = {})
    vm.vm_destroy
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_reboot_guest(vm, options = {})
    vm.reboot_guest
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_reset(vm, options = {})
    vm.reset
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  # TODO: Should this be in a VM-specific subclass or mixin?
  #       This is a general EMS question.
  def vm_create_evm_snapshot(vm, options = {})
    require "OpenStackExtract/MiqOpenStackVm/MiqOpenStackInstance"

    log_prefix = "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}]"

    miq_openstack_instance = MiqOpenStackInstance.new(vm.ems_ref, openstack_handle)
    miq_snapshot = miq_openstack_instance.create_evm_snapshot(options)

    # Add new snapshot image to the vms table. Type is TemplateOpenstack.
    miq_templates.create!(
      :type     => "TemplateOpenstack",
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
    $log.error "#{log_prefix}, error: #{err}"
    $log.debug err.backtrace.join("\n") if $log.debug?
    raise
  end

  def vm_delete_evm_snapshot(vm, image_id)
    require "OpenStackExtract/MiqOpenStackVm/MiqOpenStackInstance"

    log_prefix = "MIQ(#{self.class.name}##{__method__}) snapshot=[#{image_id}]"

    miq_openstack_instance = MiqOpenStackInstance.new(vm.ems_ref, openstack_handle)
    miq_openstack_instance.delete_evm_snapshot(image_id)

    # Remove from the snapshots table.
    ar_snapshot = vm.snapshots.where(:ems_ref  => image_id).first
    $log.debug "#{log_prefix}: ar_snapshot = #{ar_snapshot.class.name}"
    ar_snapshot.destroy if ar_snapshot

    # Remove from the vms table.
    ar_template = miq_templates.where(:ems_ref  => image_id).first
    $log.debug "#{log_prefix}: ar_template = #{ar_template.class.name}"
    ar_template.destroy if ar_template
  rescue => err
    $log.error "#{log_prefix}, error: #{err}"
    $log.debug err.backtrace.join("\n") if $log.debug?
    raise
  end
end
