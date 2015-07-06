module VmOrTemplate::Operations
  include_concern 'Configuration'
  include_concern 'Power'
  include_concern 'Relocation'
  include_concern 'Snapshot'
  include_concern 'SmartState'

  alias ruby_clone clone

  def raw_clone(name, folder, pool=nil, host=nil, datastore=nil, powerOn=false, template_flag=false, transform=nil, config=nil, customization=nil, disk=nil)
    raise "VM has no EMS, unable to clone" unless self.ext_management_system
    folder_mor    = folder.ems_ref_obj    if folder.respond_to?(:ems_ref_obj)
    pool_mor      = pool.ems_ref_obj      if pool.respond_to?(:ems_ref_obj)
    host_mor      = host.ems_ref_obj      if host.respond_to?(:ems_ref_obj)
    datastore_mor = datastore.ems_ref_obj if datastore.respond_to?(:ems_ref_obj)
    run_command_via_parent(:vm_clone, :name => name, :folder => folder_mor, :pool => pool_mor, :host => host_mor, :datastore => datastore_mor, :powerOn => powerOn, :template => template_flag, :transform => transform, :config => config, :customization => customization, :disk => disk)
  end

  def clone(name, folder, pool=nil, host=nil, datastore=nil, powerOn=false, template_flag=false, transform=nil, config=nil, customization=nil, disk=nil)
    raw_clone(name, folder, pool, host, datastore, powerOn, template_flag, transform, config, customization, disk)
  end

  def raw_mark_as_template
    raise "VM has no EMS, unable to mark as template" unless self.ext_management_system
    run_command_via_parent(:vm_mark_as_template)
  end

  def mark_as_template
    raw_mark_as_template
  end

  def raw_mark_as_vm(pool, host = nil)
    raise "VM has no EMS, unable to mark as vm" unless self.ext_management_system
    pool_mor = pool.ems_ref_obj if pool.respond_to?(:ems_ref_obj)
    host_mor = host.ems_ref_obj if host.respond_to?(:ems_ref_obj)
    run_command_via_parent(:vm_mark_as_vm, :pool => pool_mor, :host => host_mor)
  end

  def mark_as_vm(pool, host = nil)
    raw_mark_as_vm(pool, host)
  end

  def raw_unregister
    raise "VM has no #{ui_lookup(:table => "ext_management_systems")}, unable to unregister VM" unless self.ext_management_system
    run_command_via_parent(:vm_unregister)
  end

  def unregister
    raw_unregister unless policy_prevented?(:request_vm_unregister)
  end

  def raw_destroy
    raise "VM has no #{ui_lookup(:table => "ext_management_systems")}, unable to destroy VM" unless self.ext_management_system
    run_command_via_parent(:vm_destroy)
  end

  def vm_destroy
    raw_destroy unless policy_prevented?(:request_vm_destroy)
  end

  private

  #
  # UI button validation methods
  #

  def validate_vm_control
    # Check the basic require to interact with a VM.
    return [false, 'The VM is retired'] if self.retired?
    return [false, 'The VM is a template'] if self.template?
    return [true,  'The VM is not connected to a Host'] unless self.has_required_host?
    return [true,  'The VM does not have a valid connection state'] if !self.connection_state.nil? && !self.connected_to_ems?
    return [true,  "The VM is not connected to an active #{ui_lookup(:table => "ext_management_systems")}"] unless self.has_active_ems?
    return nil
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
    return {:available => true,   :message => nil}  if self.current_state.send(check_powered_on ? "==" : "!=", "on")
    return {:available => false,  :message => "The VM is#{" not" if check_powered_on} powered on"}
  end
end
