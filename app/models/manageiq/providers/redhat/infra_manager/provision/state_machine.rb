module ManageIQ::Providers::Redhat::InfraManager::Provision::StateMachine
  def create_destination
    signal :determine_placement
  end

  def determine_placement
    placement

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
      EmsRefresh.queue_refresh(dest_cluster.ext_management_system)
      signal :poll_destination_in_vmdb
    else
      requeue_phase
    end
  end

  def customize_destination
    if destination_image_locked?
      _log.info("Destination image locked; re-queuing")
      requeue_phase
    else
      message = "Starting New #{destination_type} Customization"
      _log.info("#{message} #{for_destination}")
      update_and_notify_parent(:message => message)
      configure_container
      attach_floppy_payload

      signal :poll_destination_powered_off_in_provider
    end
  end

  def poll_destination_powered_on_in_provider
    update_and_notify_parent(:message => "Waiting for provider PowerOn of #{for_destination}")
    raise MiqException::MiqProvisionError, "VM Failed to start" if phase_context[:power_on_wait_count].to_i > 120

    if destination.with_provider_object(&:status)[:state] == "up"
      signal :poll_destination_powered_off_in_provider
    else
      phase_context[:power_on_wait_count] ||= 0
      phase_context[:power_on_wait_count]  += 1
      requeue_phase
    end
  end

  def poll_destination_powered_off_in_provider
    update_and_notify_parent(:message => "Waiting for provider PowerOff of #{for_destination}")

    if powered_off_in_provider?
      signal :poll_destination_powered_off_in_vmdb
    else
      requeue_phase
    end
  end

  private

  def powered_off_in_provider?
    destination.with_provider_object(&:status)[:state] == "down"
  end
end
