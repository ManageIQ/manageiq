module CockpitSupportMixin
  extend ActiveSupport::Concern

  included do
    supports :cockpit_console do
      if respond_to?(:platform) && platform == 'windows'
        unsupported_reason_add(:cockpit_console, _("The web-based console is not available because the Windows platform is not supported"))
      end
      unsupported_reason_add(:cockpit_console,
                             _("The web-based console is not available because the 'Cockpit' role is not enabled")) unless MiqRegion.my_region.role_active?('cockpit_ws')
    end

    supports :launch_cockpit do
      if respond_to?(:power_state)
        vm_cockpit_support
      else
        container_cockpit_support
      end
    end
  end

  private

  def vm_cockpit_support
    unsupported_reason_add(:launch_cockpit, 'Launching of Cockpit requires an IP address for the VM.') if ipaddresses.blank?
    unsupported_reason_add(:launch_cockpit, 'The web-based console is not available because the VM is not powered on') if power_state != 'on'
  end

  def container_cockpit_support
    unsupported_reason_add(:launch_cockpit, 'The web-based console is not available because the Container Node is not powered on') if ready_condition_status != 'True'
    unsupported_reason_add(:launch_cockpit, 'Launching of Cockpit requires an IP address.') if ipaddress.blank?
  end
end
