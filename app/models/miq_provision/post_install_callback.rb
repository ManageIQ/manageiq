module MiqProvision::PostInstallCallback
  extend ActiveSupport::Concern

  # This method will be called via callback if the installer is unable to shut itself down.  If the state machine is
  # waiting for the VM poweroff, we stop the VM. (:poll_destination_powered_off_in_vmdb, :poll_destination_powered_off_in_provider)
  # The state machine (running on a different worker) will continue when the VM is off.
  def post_install_callback
    if phase.to_s.include?("poll_destination_powered_off")
      _log.info("Powering Off #{for_destination}")

      destination.stop
    else
      _log.info("No action needed in post_install_callback for current phase [#{phase}] for #{for_destination}")
    end
  end
end
