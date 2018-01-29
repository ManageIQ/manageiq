module Vm::Operations
  extend ActiveSupport::Concern

  include CockpitMixin
  include CockpitSupportMixin

  include_concern 'Guest'
  include_concern 'Power'
  include_concern 'Lifecycle'

  included do
    supports :vnc_console do
      message = "VNC Console not supported"
      if vendor == 'vmware'
        unsupported_reason_add(:vnc_console, message) unless ext_management_system.present? && console_supports_type?('VNC')
      elsif !console_supported?('VNC')
        unsupported_reason_add(:vnc_console, message)
      end
    end

    supports :mks_console do
      message = "WebMKS Console not supported"
      if vendor != 'vmware'
        unsupported_reason_add(:mks_console, message)
      elsif console_supported?('WEBMKS') && !console_supports_type?('WebMKS')
        unsupported_reason_add(:mks_console, message)
      end
    end

    supports :vmrc_console do
      unsupported_reason_add(:vmrc_console, "VMRC Console not supported") unless console_supports_type?('VMRC')
    end

    supports :spice_console do
      unsupported_reason_add(:spice_console, "Spice Console not supported") unless console_supports_type?('SPICE')
    end

    supports :launch_vnc_console do
      if vendor == 'vmware' && ext_management_system.try(:api_version).to_f >= 6.5
        unsupported_reason_add(:launch_vnc_console, _('VNC consoles are unsupported on VMware ESXi 6.5 and later.'))
      elsif power_state != 'on'
        unsupported_reason_add(:launch_vnc_console, _('The web-based VNC console is not available because the VM is not powered on'))
      end
    end

    supports :launch_vmrc_console do
      begin
        validate_remote_console_vmrc_support
      rescue => err
        unsupported_reason_add(:launch_vmrc_console, _('VM VMRC Console error: %{error}') % {:error => err})
      end
    end

    supports :launch_mks_console do
      if power_state != 'on'
        unsupported_reason_add(:launch_mks_console,  _('The web-based WebMKS console is not available because the VM is not powered on'))
      elsif !Rails.root.join('public', 'webmks').exist?
        unsupported_reason_add(:launch_mks_console, _("The web-based WebMKS console is not available because the required libraries aren't installed"))
      end
    end

    supports :launch_spice_console do
      if power_state != 'on'
        unsupported_reason_add(:launch_spice_console, _('The web-based spice console is not available because the VM is not powered on'))
      end
    end
  end

  def cockpit_url
    return if ipaddresses.blank?
    MiqCockpit::WS.url(cockpit_server, cockpit_worker, ipv4_address || ipaddresses.first)
  end

  def ipv4_address
    return public_address unless public_address.nil?
    ipaddresses.find { |ip| IPAddr.new(ip).ipv4? && !ip.starts_with?('192') }
  end

  def public_address
    ipaddresses.find { |ip| !Addrinfo.tcp(ip, 80).ipv4_private? && IPAddr.new(ip).ipv4? }
  end

  def validate_collect_running_processes
    s = {:available => false, :message => nil}

    # Report reasons why collection is not available for this VM
    unless ['windows'].include?(platform)
      s[:message] = 'VM Process collection is only available for Windows VMs.'
      return s
    end
    unless self.runnable?
      s[:message] = 'VM Process collection is only available for Runnable VMs.'
      return s
    end

    # From here on out collection is possible, but may not be currently available.
    s[:available] = true
    unless state == "on"
      s[:message] = 'VM Process collection is only available while the VM is powered on.'
      return s
    end

    if my_zone.nil? || my_zone_obj.auth_user_pwd(:windows_domain).nil?
      s[:message] = 'VM Process collection requires credentials set at the Zone level.'
      return s
    end

    if ipaddresses.blank?
      s[:message] = 'VM Process collection requires an IP address for the VM.'
      return s
    end

    s
  end
end
