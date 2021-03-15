module MiqTemplate::Operations
  extend ActiveSupport::Concern

  included do
    supports     :clone
    supports_not :collect_running_processes, :reason => _("Process Collection is not available for Images and VM Templates.")
    supports_not :pause,                     :reason => _("Pause Operation is not available for Images and VM Templates.")
    supports_not :provisioning,              :reason => _("Provisioning Operation is not available for Images and VM Templates.")
    supports_not :reboot_guest,              :reason => _("Reboot Guest Operation is not available for Images and VM Templates.")
    supports_not :reset,                     :reason => _("Reset Operation is not available for Images and VM Templates.")
    supports_not :retire,                    :reason => _("Retire Operation is not available for Images and VM Templates.")
    supports_not :shutdown_guest,            :reason => _("Shutdown Guest Operation is not available for Images and VM Templates.")
    supports_not :standby_guest,             :reason => _("Standby Guest Operation is not available for Images and VM Templates.")
    supports_not :start,                     :reason => _("Start Operation is not available for Images and VM Templates.")
    supports_not :stop,                      :reason => _("Stop Operation is not available for Images and VM Templates.")
    supports_not :suspend,                   :reason => _("Suspend Operation is not available for Images and VM Templates.")
  end
end
