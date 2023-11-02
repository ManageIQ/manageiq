module MiqTemplate::Operations
  extend ActiveSupport::Concern

  included do
    supports     :clone
    supports_not :collect_running_processes
    supports_not :pause
    supports_not :provisioning
    supports_not :reboot_guest
    supports_not :reset
    supports_not :retire
    supports_not :shutdown_guest
    supports_not :standby_guest
    supports_not :start
    supports_not :stop
    supports_not :suspend
  end
end
