module PhysicalServerProvisionTask::StateMachine
  def run_provision
    raise MiqException::MiqProvisionError, "Unable to find #{model_class} with id #{source_id.inspect}" if source.blank?
    dump_obj(options, "MIQ(#{self.class.name}##{__method__}) options: ", $log, :info)
    signal :start_provisioning
  end

  def start_provisioning
    # Implement provisioning in subclass, user-defined values are stored in options field.
    raise NotImplementedError, 'Must be implemented in subclass and signal :done_provisioning when done'
  end

  def done_provisioning
    update_and_notify_parent(:message => msg('done provisioning'))
    signal :mark_as_completed
  end

  def mark_as_completed
    update_and_notify_parent(:state => 'finished', :message => msg('provisioning completed'))
    MiqEvent.raise_evm_event(source, 'generic_task_finish', :message => "Done provisioning PhysicalServer")
    signal :finish
  end

  def finish
    if status != 'Error'
      _log.info("Executing provision task: [#{description}]... Complete")
    else
      _log.info("Executing provision task: [#{description}]... Errored")
    end
  end

  def msg(txt)
    "Provisioning PhysicalServer id=#{source.id}, name=#{source.name}, ems_ref=#{source.ems_ref}: #{txt}"
  end
end
