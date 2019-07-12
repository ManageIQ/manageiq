module PhysicalServerFirmwareUpdateTask::StateMachine
  def run_firmware_update
    dump_obj(options, "MIQ(#{self.class.name}##{__method__}) options: ", $log, :info)
    signal :start_firmware_update
  end

  def start_firmware_update
    # Implement firmware update in subclass, user-defined values are stored in options field.
    # Affected servers can be accessed via miq_request.affected_physical_servers
    raise NotImplementedError, 'Must be implemented in subclass and signal :done_firmware_update when done'
  end

  def done_firmware_update
    update_and_notify_parent(:message => msg('done updating firmware'))
    signal :mark_as_completed
  end

  def mark_as_completed
    update_and_notify_parent(:state => 'finished', :message => msg('firmware update completed'))
    signal :finish
  end

  def finish
    if status != 'Error'
      _log.info("Executing firmware update task: [#{description}]... Complete")
    else
      _log.info("Executing firmware update task: [#{description}]... Errored")
    end
  end

  def msg(txt)
    "Updating firmware for PhysicalServer(s): #{txt}"
  end
end
