module ManageIQ::Providers::CloudManager::Provision::StateMachine
  def create_destination
    signal :determine_placement
  end

  def determine_placement
    availability_zone = placement
    options[:dest_availability_zone] = [availability_zone.try(:id), availability_zone.try(:name)]
    signal :prepare_volumes
  end

  def prepare_volumes
    if options[:volumes]
      phase_context[:requested_volumes] = create_requested_volumes(options[:volumes])
      signal :poll_volumes_complete
    else
      signal :prepare_provision
    end
  end

  def poll_volumes_complete
    status, status_message = do_volume_creation_check(phase_context[:requested_volumes])
    status_message = "completed prepare provision work queued" if status
    message = "Volume creation is #{status_message}"
    _log.info(message)
    update_and_notify_parent(:message => message)
    if status
      signal :prepare_provision
    else
      requeue_phase
    end
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
    _log.info(message)
    update_and_notify_parent(:message => message)

    if clone_status
      clone_task_ref = phase_context.delete(:clone_task_ref)
      phase_context[:new_vm_ems_ref] = clone_task_ref

      manager = source.ext_management_system
      if manager.inventory_object_refresh? && manager.allow_targeted_refresh?
        # Queue new targeted refresh if allowed
        vm_target = ManagerRefresh::Target.new(:manager     => manager,
                                               :association => :vms,
                                               :manager_ref => {:ems_ref => clone_task_ref})
        EmsRefresh.queue_refresh(vm_target)
      else
        # Otherwise queue a full refresh
        EmsRefresh.queue_refresh(manager)
      end
      signal :poll_destination_in_vmdb
    else
      requeue_phase
    end
  end

  def customize_destination
    message = "Customizing #{for_destination}"
    _log.info("#{message} #{for_destination}")
    update_and_notify_parent(:message => message)

    if floating_ip
      _log.info("Associating floating IP address [#{floating_ip.address}] to #{for_destination}")
      associate_floating_ip(floating_ip)
    end

    signal :post_create_destination
  end
end
