module Vm::Operations
  extend ActiveSupport::Concern

  include CockpitMixin
  include CockpitSupportMixin

  include_concern 'Guest'
  include_concern 'Power'
  include_concern 'Lifecycle'

  included do
    supports :html5_console do
      consup = %w[vnc webmks spice].any? { |type| send(:console_supported?, type) }
      unsupported_reason_add(:html5_console, _("The web-based HTML5 Console is not supported")) unless consup
    end

    supports :vmrc_console do
      unsupported_reason_add(:vmrc_console, _("VMRC Console not supported")) unless console_supported?('VMRC')
    end

    supports :native_console do
      unsupported_reason_add(:native_console, _("VM NATIVE Console not supported")) unless console_supported?('NATIVE')
    end

    supports :launch_html5_console do
      unsupported_reason_add(:launch_html5_console, _("The web-based HTML5 Console is not available because the VM is not powered on")) unless power_state == 'on'
    end

    supports :launch_vmrc_console do
      begin
        validate_remote_console_vmrc_support
      rescue => err
        unsupported_reason_add(:launch_vmrc_console, _('VM VMRC Console error: %{error}') % {:error => err})
      end
    end

    supports :launch_native_console do
      validate_native_console_support
    rescue StandardError => err
      unsupported_reason_add(:launch_native_console, _('VM NATIVE Console error: %{error}') % {:error => err})
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
