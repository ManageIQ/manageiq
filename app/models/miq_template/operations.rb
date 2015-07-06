module MiqTemplate::Operations

  def validate_collect_running_processes
    validate_invalid_for_template("VM Process collection")
  end

  def validate_start
    validate_invalid_for_template("Start Operation")
  end

  def validate_stop
    validate_invalid_for_template("Stop Operation")
  end

  def validate_suspend
    validate_invalid_for_template("Suspend Operation")
  end

  def validate_pause
    validate_invalid_for_template("Pause Operation")
  end

  def validate_shutdown_guest
    validate_invalid_for_template("Shutdown Guest Operation")
  end

  def validate_standby_guest
    validate_invalid_for_template("Standby Guest Operation")
  end

  def validate_reboot_guest
    validate_invalid_for_template("Reboot Guest Operation")
  end

  def validate_reset
    validate_invalid_for_template("Reset Operation")
  end

  private

  def validate_invalid_for_template(message_prefix)
    { :available => false, :message => "#{message_prefix} is not available for Images/Templates." }
  end

end
