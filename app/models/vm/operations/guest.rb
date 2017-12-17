module Vm::Operations::Guest
  extend ActiveSupport::Concern

  included do
    api_relay_method :shutdown_guest
    api_relay_method :reboot_guest
    api_relay_method :reset
  end

  def validate_standby_guest
    validate_unsupported("Standby Guest Operation")
  end

  def raw_shutdown_guest
    unless has_active_ems?
      raise _("VM has no Provider, unable to shutdown guest OS")
    end
    run_command_via_parent(:vm_shutdown_guest)
  end

  def shutdown_guest
    check_policy_prevent(:request_vm_shutdown_guest, :raw_shutdown_guest)
  end

  def raw_standby_guest
    unless has_active_ems?
      raise _("VM has no Provider, unable to standby guest OS")
    end
    run_command_via_parent(:vm_standby_guest)
  end

  def standby_guest
    check_policy_prevent(:request_vm_standby_guest, :raw_standby_guest)
  end

  def raw_reboot_guest
    unless has_active_ems?
      raise _("VM has no Provider, unable to reboot guest OS")
    end
    run_command_via_parent(:vm_reboot_guest)
  end

  def reboot_guest
    check_policy_prevent(:request_vm_reboot_guest, :raw_reboot_guest)
  end

  def raw_reset
    unless has_active_ems?
      raise _("VM has no Provider, unable to reset VM")
    end
    run_command_via_parent(:vm_reset)
  end

  def reset
    check_policy_prevent(:request_vm_reset, :raw_reset)
  end
end
