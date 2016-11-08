module Vm::Operations
  extend ActiveSupport::Concern

  include_concern 'Guest'
  include_concern 'Power'
  include_concern 'Lifecycle'

  included do
    supports :launch_cockpit do
      if ipaddresses.blank?
        unsupported_reason_add :launch_cockpit, 'Launching of Cockpit requires an IP address for the VM.'
      end
    end
  end

  def cockpit_url
    return if ipaddresses.blank?
    miq_server = ext_management_system.nil? ? nil : ext_management_system.zone.remote_cockpit_ws_miq_server
    MiqCockpit::WS.url(miq_server,
                       MiqCockpitWsWorker.fetch_worker_settings_from_server(miq_server),
                       ipaddresses.first)
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
