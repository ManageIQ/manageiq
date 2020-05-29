module VmOrTemplate::Operations
  extend ActiveSupport::Concern

  include_concern 'Configuration'
  include_concern 'Power'
  include_concern 'Relocation'
  include_concern 'Snapshot'
  include_concern 'SmartState'

  alias_method :ruby_clone, :clone

  def raw_clone(name, folder, pool = nil, host = nil, datastore = nil, powerOn = false, template_flag = false, transform = nil, config = nil, customization = nil, disk = nil)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def clone(name, folder, pool = nil, host = nil, datastore = nil, powerOn = false, template_flag = false, transform = nil, config = nil, customization = nil, disk = nil)
    raise _("VM has no EMS, unable to clone") unless ext_management_system

    raw_clone(name, folder, pool, host, datastore, powerOn, template_flag, transform, config, customization, disk)
  end

  def raw_mark_as_template
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def mark_as_template
    raise _("VM has no EMS, unable to mark as template") unless ext_management_system

    raw_mark_as_template
  end

  def raw_mark_as_vm(pool, host = nil)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def mark_as_vm(pool, host = nil)
    raise _("VM has no EMS, unable to mark as vm") unless ext_management_system

    raw_mark_as_vm(pool, host)
  end

  def raw_unregister
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def unregister_queue
    run_command_via_queue("raw_unregister")
  end

  def unregister
    raise _("VM has no Provider, unable to unregister VM") unless ext_management_system

    check_policy_prevent(:request_vm_unregister, :unregister_queue)
  end

  def raw_destroy
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def destroy_queue
    run_command_via_queue("raw_destroy")
  end

  def vm_destroy
    raise _("VM has no Provider, unable to destroy VM") unless ext_management_system

    check_policy_prevent(:request_vm_destroy, :destroy_queue)
  end

  def raw_rename(new_name)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def rename(new_name)
    raise _("VM has no Provider, unable to rename VM") unless ext_management_system

    raw_rename(new_name)
  end

  def rename_queue(userid, new_name)
    task_opts = {
      :action => "Renaming VM for user #{userid}",
      :userid => userid
    }

    run_command_via_task(task_opts, :method_name => "rename", :args => [new_name])
  end

  def raw_set_custom_field(_attribute, _value)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def set_custom_field(attribute, value)
    raise _("VM has no EMS, unable to set custom attribute") unless ext_management_system

    raw_set_custom_field(attribute, value)
  end

  def log_user_event(user_event)
    $log.info(user_event)
  end

  private

  #
  # UI button validation methods
  #

  def validate_vm_control_shelve_action
    unless supports_control?
      return {:available => false, :message => unsupported_reason(:control)}
    end
    return {:available => true,   :message => nil}  if %w(on off suspended paused).include?(current_state)
    {:available => false,  :message => "The VM can't be shelved, current state has to be powered on, off, suspended or paused"}
  end

  def validate_vm_control_shelve_offload_action
    unless supports_control?
      return {:available => false, :message => unsupported_reason(:control)}
    end
    return {:available => true,   :message => nil}  if %w(shelved).include?(current_state)
    {:available => false,  :message => "The VM can't be shelved offload, current state has to be shelved"}
  end

  included do
    supports :control do
      msg = if retired?
              _('The VM is retired')
            elsif template?
              _('The VM is a template')
            elsif terminated?
              _('The VM is terminated')
            elsif !has_required_host?
              _('The VM is not connected to a Host')
            elsif disconnected?
              _('The VM does not have a valid connection state')
            elsif !has_active_ems?
              _("The VM is not connected to an active Provider")
            end
      unsupported_reason_add(:control, msg) if msg
    end
  end

  def validate_vm_control_powered_on
    validate_vm_control_power_state(true)
  end

  def validate_vm_control_power_state(check_powered_on)
    unless supports_control?
      return {:available => false, :message => unsupported_reason(:control)}
    end
    return {:available => true,   :message => nil}  if current_state.send(check_powered_on ? "==" : "!=", "on")
    {:available => false,  :message => "The VM is#{" not" if check_powered_on} powered on"}
  end

  def validate_unsupported(message_prefix)
    {:available => false, :message => "#{message_prefix} is not available for #{self.class.model_suffix} VM or Template."}
  end
end
