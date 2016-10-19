module ManageIQ::Providers::Redhat::InfraManager::Vm::Operations::Guest
  extend ActiveSupport::Concern

  included do
    supports :shutdown_guest do
      unsupported_reason_add(:shutdown_guest, unsupported_reason(:control)) unless supports_control?
      unsupported_reason_add(:shutdown_guest, _("The VM is not powered on")) unless current_state == "on"
    end
  end

  def raw_shutdown_guest
    with_provider_object(&:shutdown)
  rescue Ovirt::VmIsNotRunning
  end
end
