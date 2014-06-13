module MiqProvisionRedhat::StateMachine
  def create_destination
    signal :determine_placement
  end

  def determine_placement
    self.placement

    signal :prepare_provision
  end

  def start_clone_task
    update_and_notify_parent(:message => "Starting Clone of #{clone_direction}")

    log_clone_options(self.phase_context[:clone_options])
    start_clone(self.phase_context[:clone_options])
    self.phase_context.delete(:clone_options)

    signal :poll_clone_complete
  end

  def poll_clone_complete
    update_and_notify_parent(:message => "Waiting for clone of #{clone_direction}")

    if clone_complete?
      self.phase_context.delete(:clone_task_ref)
      EmsRefresh.queue_refresh(dest_cluster.ext_management_system)
      signal :poll_destination_in_vmdb
    else
      requeue_phase
    end
  end

  def customize_destination
    if destination_image_locked?
      $log.info("MIQ(#{self.class.name}#customize_destination) Destination image locked; re-queuing")
      requeue_phase
    else
      message = "Starting New #{destination_type} Customization"
      $log.info("MIQ(#{self.class.name}#customize_destination) #{message} #{for_destination}")
      update_and_notify_parent(:message => message)
      configure_container
      attach_floppy_payload

      signal :poll_destination_powered_off_in_vmdb
    end
  end

  private

  def clone_direction
    "[#{self.source.name}] to #{destination_type} [#{dest_name}]"
  end

  def for_destination
    "#{destination_type} id: [#{self.destination.id}], name: [#{dest_name}]"
  end

end
