module Vm::Operations::Guest

  extend ActiveSupport::Concern
  include SupportsFeatureMixin

  included do
    supports_not :shutdown_guest, :reason => _("Shutdown guest operation is not available for VM or Template.")
    supports_not :standby_guest, :reason => _("Standby Guest Operation is not available for VM or Template.")
    supports_not :reboot_guest, :reason => _("Reboot Guest Operation is not available for VM or Template.")
    supports_not :reset, :reason => _("Reset Guest Operation is not available for VM or Template.")
  end

  def raw_shutdown_guest
    unless has_active_ems?
      raise _("VM has no %{table}, unable to shutdown guest OS") %
              {:table => ui_lookup(:table => "ext_management_systems")}
    end
    run_command_via_parent(:vm_shutdown_guest)
  end

  def shutdown_guest
    check_policy_prevent(:request_vm_shutdown_guest, :raw_shutdown_guest)
  end

  def raw_standby_guest
    unless has_active_ems?
      raise _("VM has no %{table}, unable to standby guest OS") %
              {:table => ui_lookup(:table => "ext_management_systems")}
    end
    run_command_via_parent(:vm_standby_guest)
  end

  def standby_guest
    check_policy_prevent(:request_vm_standby_guest, :raw_standby_guest)
  end

  def raw_reboot_guest
    unless has_active_ems?
      raise _("VM has no %{table}, unable to reboot guest OS") %
              {:table => ui_lookup(:table => "ext_management_systems")}
    end
    run_command_via_parent(:vm_reboot_guest)
  end

  def reboot_guest
    check_policy_prevent(:request_vm_reboot_guest, :raw_reboot_guest)
  end

  def raw_reset
    unless has_active_ems?
      raise _("VM has no %{table}, unable to reset VM") % {:table => ui_lookup(:table => "ext_management_systems")}
    end
    run_command_via_parent(:vm_reset)
  end

  def reset
    check_policy_prevent(:request_vm_reset, :raw_reset)
  end
end
