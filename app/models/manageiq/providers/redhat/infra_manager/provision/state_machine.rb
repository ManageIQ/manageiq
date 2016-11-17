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
      # Full refresh was removed from here because it is expensive on larger envs
      # With this change we rely on eventing and tagreted refresh it triggers
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
      signal :customize_guest
    end
  end

  def customize_guest
    signal :poll_destination_powered_off_in_provider
  end

  def autostart_destination
    destination.custom_attributes.create!(:name => "miq_provision_boot_with_cloud_init") if phase_context[:boot_with_cloud_init]

    super
  end

  private

  def powered_off_in_provider?
    destination.with_provider_object(&:status)[:state] == "down"
  end

  def powered_on_in_provider?
    destination.with_provider_object(&:status)[:state] == "up"
  end
end
