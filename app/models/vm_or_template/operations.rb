module VmOrTemplate::Operations
  include_concern 'Configuration'
  include_concern 'Power'
  include_concern 'Relocation'
  include_concern 'Snapshot'
  include_concern 'SmartState'

  alias_method :ruby_clone, :clone

  def raw_clone(name, folder, pool = nil, host = nil, datastore = nil, powerOn = false, template_flag = false, transform = nil, config = nil, customization = nil, disk = nil)
    raise _("VM has no EMS, unable to clone") unless ext_management_system
    folder_mor    = folder.ems_ref_obj    if folder.respond_to?(:ems_ref_obj)
    pool_mor      = pool.ems_ref_obj      if pool.respond_to?(:ems_ref_obj)
    host_mor      = host.ems_ref_obj      if host.respond_to?(:ems_ref_obj)
    datastore_mor = datastore.ems_ref_obj if datastore.respond_to?(:ems_ref_obj)
    run_command_via_parent(:vm_clone, :name => name, :folder => folder_mor, :pool => pool_mor, :host => host_mor, :datastore => datastore_mor, :powerOn => powerOn, :template => template_flag, :transform => transform, :config => config, :customization => customization, :disk => disk)
  end

  def clone(name, folder, pool = nil, host = nil, datastore = nil, powerOn = false, template_flag = false, transform = nil, config = nil, customization = nil, disk = nil)
    raw_clone(name, folder, pool, host, datastore, powerOn, template_flag, transform, config, customization, disk)
  end

  def raw_mark_as_template
    raise _("VM has no EMS, unable to mark as template") unless ext_management_system
    run_command_via_parent(:vm_mark_as_template)
  end

  def mark_as_template
    raw_mark_as_template
  end

  def raw_mark_as_vm(pool, host = nil)
    raise _("VM has no EMS, unable to mark as vm") unless ext_management_system
    pool_mor = pool.ems_ref_obj if pool.respond_to?(:ems_ref_obj)
    host_mor = host.ems_ref_obj if host.respond_to?(:ems_ref_obj)
    run_command_via_parent(:vm_mark_as_vm, :pool => pool_mor, :host => host_mor)
  end

  def mark_as_vm(pool, host = nil)
    raw_mark_as_vm(pool, host)
  end

  def raw_unregister
    unless ext_management_system
      raise _("VM has no %{table}, unable to unregister VM") % {:table => ui_lookup(:table => "ext_management_systems")}
    end
    run_command_via_parent(:vm_unregister)
  end

  def unregister
    check_policy_prevent(:request_vm_unregister, :raw_unregister)
  end

  def raw_destroy
    unless ext_management_system
      raise _("VM has no %{table}, unable to destroy VM") % {:table => ui_lookup(:table => "ext_management_systems")}
    end
    run_command_via_parent(:vm_destroy)
  end

  def vm_destroy
    check_policy_prevent(:request_vm_destroy, :raw_destroy)
  end

  private

  #
  # UI button validation methods
  #

  def validate_vm_control_shelve_action
    msg = validate_vm_control
    return {:available => msg[0], :message => msg[1]} unless msg.nil?
    return {:available => true,   :message => nil}  if %w(on off suspended paused).include?(current_state)
    {:available => false,  :message => "The VM can't be shelved, current state has to be powered on, off, suspended or paused"}
  end

  def validate_vm_control_shelve_offload_action
    msg = validate_vm_control
    return {:available => msg[0], :message => msg[1]} unless msg.nil?
    return {:available => true,   :message => nil}  if %w(shelved).include?(current_state)
    {:available => false,  :message => "The VM can't be shelved offload, current state has to be shelved"}
  end

  def validate_vm_control
    # Check the basic require to interact with a VM.
    return [false, 'The VM is retired'] if self.retired?
    return [false, 'The VM is a template'] if self.template?
    return [false, 'The VM is terminated'] if self.terminated?
    return [true,  'The VM is not connected to a Host'] unless self.has_required_host?
    return [true,  'The VM does not have a valid connection state'] if !connection_state.nil? && !self.connected_to_ems?
    return [true,  "The VM is not connected to an active #{ui_lookup(:table => "ext_management_systems")}"] unless self.has_active_ems?
    nil
  end

  def validate_terminate
    return {:available => false, :message => 'The VM is terminated'} if self.terminated?
    {:available => true, :message => nil}
  end

  def validate_vm_control_powered_on
    validate_vm_control_power_state(true)
  end

  def validate_vm_control_not_powered_on
    validate_vm_control_power_state(false)
  end

  def validate_vm_control_power_state(check_powered_on)
    msg = validate_vm_control
    return {:available => msg[0], :message => msg[1]} unless msg.nil?
    return {:available => true,   :message => nil}  if current_state.send(check_powered_on ? "==" : "!=", "on")
    {:available => false,  :message => "The VM is#{" not" if check_powered_on} powered on"}
  end

  def validate_unsupported(message_prefix)
    {:available => false, :message => "#{message_prefix} is not available for #{self.class.model_suffix} VM or Template."}
  end
end
