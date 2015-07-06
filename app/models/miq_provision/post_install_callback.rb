module MiqProvision::PostInstallCallback
  extend ActiveSupport::Concern

  # This method will be called via callback if the VM is unable to shut itself down.
  # If called, we just stop the VM.  The state machine (running on a different worker)
  # will be waiting for the power off.
  def post_install_callback
    if phase.to_sym == :poll_destination_powered_off_in_vmdb
      _log.info("Powering Off #{for_destination}")

      destination.stop
    else
      _log.info("No action needed in post_install_callback for current phase [#{phase}] for #{for_destination}")
    end
  end
end
