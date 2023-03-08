module Vm::Operations
  extend ActiveSupport::Concern

  include_concern 'Guest'
  include_concern 'Power'
  include_concern 'Lifecycle'

  included do
    supports_not :console
    supports_not :html5_console
    supports_not :native_console
    supports_not :spice_console
    supports_not :vmrc_console
    supports_not :vnc_console
    supports_not :webmks_console

    supports :launch_html5_console do
      _("The web-based HTML5 Console is not available because the VM is not powered on") unless power_state == 'on'
    end

    supports :launch_vmrc_console do
      begin
        validate_remote_console_vmrc_support
      rescue => err
        _('VM VMRC Console error: %{error}') % {:error => err}
      end
    end

    supports :launch_native_console do
      validate_native_console_support
    rescue StandardError => err
      _('VM NATIVE Console error: %{error}') % {:error => err}
    end

    supports :collect_running_processes do
      reason   = N_('VM Process collection is only available for Windows VMs.') unless ['windows'].include?(platform)
      reason ||= N_('VM Process collection is only available for Runnable VMs.') unless self.runnable?
      reason ||= N_('VM Process collection is only available while the VM is powered on.') unless state == "on"
      reason ||= N_('VM Process collection requires credentials set at the Zone level.') if my_zone.nil? || my_zone_obj.auth_user_pwd(:windows_domain).nil?
      reason ||= N_('VM Process collection requires an IP address for the VM.') if ipaddresses.blank?

      reason
    end

    supports_not :evacuate
    supports_not :reconfigure_disks
    supports_not :reconfigure_disksize
    supports_not :reconfigure_network_adapters
    supports_not :reconfigure_cdroms
    supports_not :remove_security_group
    supports_not :resize
  end

  def ipv4_address
    return public_address unless public_address.nil?
    ipaddresses.find { |ip| IPAddr.new(ip).ipv4? && !ip.starts_with?('192') }
  end

  def public_address
    ipaddresses.find { |ip| !Addrinfo.tcp(ip, 80).ipv4_private? && IPAddr.new(ip).ipv4? }
  end
end
