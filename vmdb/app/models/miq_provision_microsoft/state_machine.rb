module MiqProvisionMicrosoft::StateMachine
  def create_destination
    signal :determine_placement
  end

  def determine_placement
    host, datastore = self.placement

    self.options[:dest_host]    = [host.id, host.name]
    self.options[:dest_storage] = [datastore.id, datastore.name]

    signal :prepare_provision
  end

  def start_clone_task
    update_and_notify_parent(:message => "Starting Clone of #{clone_direction}")
    log_clone_options(phase_context[:clone_options])
    start_clone(phase_context[:clone_options])
    phase_context.delete(:clone_options)

    signal :poll_clone_complete
  end

  def poll_clone_complete
    update_and_notify_parent(:message => "Waiting for clone of #{clone_direction}")

    if clone_complete?
      phase_context.delete(:clone_task_ref)
      EmsRefresh.queue_refresh(dest_host.ext_management_system)
      signal :poll_destination_in_vmdb
    else
      requeue_phase
    end
  end

  def customize_destination
    update_and_notify_parent(:message => "Starting New #{destination_type} Customization")
    signal :autostart_destination
  end
end
