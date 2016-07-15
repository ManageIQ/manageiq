module MiqTemplate::Operations

  extend ActiveSupport::Concern

  included do
    supports_not :shutdown_guest, :reason => _("Shutdown guest operation is not available for Images/Templates.")
    supports_not :collect_running_processes, :reason => _("VM Process collection is not available for Images/Templates.")
    supports_not :start, :reason => _("Start Operation is not available for Images/Templates.")
    supports_not :stop, :reason => _("Stop Operation is not available for Images/Templates.")
    supports_not :suspend, :reason => _("Suspend operation is not available for Images/Templates.")
    supports_not :pause, :reason => _("Pause operation is not available for Images/Templates.")
    supports_not :standby_guest, :reason => _("Standby Guest operation is not available for Images/Templates.")
    supports_not :reboot_guest, :reason => _("Reboot Guest operation is not available for Images/Templates.")
    supports_not :reset, :reason => _("Reset operation is not available for Images/Templates.")
    supports :clone
  end
end
