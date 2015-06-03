module MiqProvisionCloud::StateMachine
  def create_destination
    signal :determine_placement
  end

  def determine_placement
    availability_zone = placement
    options[:dest_availability_zone] = [availability_zone.try(:id), availability_zone.try(:name)]
    signal :prepare_provision
  end

  def start_clone_task
    update_and_notify_parent(:message => "Starting Clone of #{clone_direction}")
    log_clone_options(phase_context[:clone_options])
    phase_context[:clone_task_ref] = start_clone(phase_context[:clone_options])
    phase_context.delete(:clone_options)
    signal :poll_clone_complete
  end

  def poll_clone_complete
    clone_status, status_message = do_clone_task_check(phase_context[:clone_task_ref])

    status_message = "completed; post provision work queued" if clone_status
    message = "Clone of #{clone_direction} is #{status_message}"
    $log.info("MIQ(#{self.class.name}#poll_clone_complete) #{message}")
    update_and_notify_parent(:message => message)

    if clone_status
      clone_task_ref = phase_context.delete(:clone_task_ref)
      phase_context[:new_vm_ems_ref] = clone_task_ref
      EmsRefresh.queue_refresh(source.ext_management_system)
      signal :poll_destination_in_vmdb
    else
      requeue_phase
    end
  end

  def customize_destination
    message = "Customizing #{for_destination}"
    $log.info("MIQ(#{self.class.name}#customize_destination) #{message} #{for_destination}")
    update_and_notify_parent(:message => message)

    if floating_ip
      $log.info("MIQ(#{self.class.name}#customize_destination) Associating floating IP address [#{floating_ip.address}] to #{for_destination}")
      associate_floating_ip(floating_ip.address)
    end

    signal :post_create_destination
  end
end
