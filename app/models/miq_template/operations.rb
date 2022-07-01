module MiqTemplate::Operations
  extend ActiveSupport::Concern

  included do
    supports     :clone
    supports_not :collect_running_processes, :reason => N_("Process Collection is not available for Images and VM Templates.")
    supports_not :pause,                     :reason => N_("Pause Operation is not available for Images and VM Templates.")
    supports_not :provisioning,              :reason => N_("Provisioning Operation is not available for Images and VM Templates.")
    supports_not :reboot_guest,              :reason => N_("Reboot Guest Operation is not available for Images and VM Templates.")
    supports_not :reset,                     :reason => N_("Reset Operation is not available for Images and VM Templates.")
    supports_not :retire,                    :reason => N_("Retire Operation is not available for Images and VM Templates.")
    supports_not :shutdown_guest,            :reason => N_("Shutdown Guest Operation is not available for Images and VM Templates.")
    supports_not :standby_guest,             :reason => N_("Standby Guest Operation is not available for Images and VM Templates.")
    supports_not :start,                     :reason => N_("Start Operation is not available for Images and VM Templates.")
    supports_not :stop,                      :reason => N_("Stop Operation is not available for Images and VM Templates.")
    supports_not :suspend,                   :reason => N_("Suspend Operation is not available for Images and VM Templates.")
  end
end
