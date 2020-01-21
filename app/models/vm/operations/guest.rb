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
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def shutdown_guest
    raise _("VM has no Provider, unable to shutdown guest OS") unless has_active_ems?

    check_policy_prevent(:request_vm_shutdown_guest, :raw_shutdown_guest)
  end

  def raw_standby_guest
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def standby_guest
    raise _("VM has no Provider, unable to standby guest OS") unless has_active_ems?

    check_policy_prevent(:request_vm_standby_guest, :raw_standby_guest)
  end

  def raw_reboot_guest
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def reboot_guest
    raise _("VM has no Provider, unable to reboot guest OS") unless has_active_ems?

    check_policy_prevent(:request_vm_reboot_guest, :raw_reboot_guest)
  end

  def raw_reset
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def reset
    raise _("VM has no Provider, unable to reset VM") unless has_active_ems?

    check_policy_prevent(:request_vm_reset, :raw_reset)
  end
end
