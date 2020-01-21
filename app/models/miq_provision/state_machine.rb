module MiqProvision::StateMachine
  def run_provision
    self.source = get_source  # just in case automate changed src_vm_id in the options hash
    signal :create_destination
  end

  def create_destination
    raise NotImplementedError,
          _("Must be implemented in subclass and signal :post_create_destination when self.destination is set")
  end

  def prepare_provision
    update_and_notify_parent(:message => "Preparing to Clone #{clone_direction}")
    phase_context[:clone_options] = prepare_for_clone_task
    dump_obj(phase_context[:clone_options], "MIQ(#{self.class.name}##{__method__}) Default Clone Options: ", $log, :info)
    phase_context[:clone_options].merge!(get_option(:clone_options) || {}).delete_nils

    signal :start_clone_task
  end

  def poll_destination_powered_off_in_provider
    update_and_notify_parent(:message => "Waiting for provider PowerOff of #{for_destination}")

    if powered_off_in_provider?
      signal :poll_destination_powered_off_in_vmdb
    else
      requeue_phase
    end
  end

  def poll_destination_powered_on_in_provider
    update_and_notify_parent(:message => "Waiting for provider PowerOn of #{for_destination}")
    raise MiqException::MiqProvisionError, _("VM Failed to start") if phase_context[:power_on_wait_count].to_i > 120

    if powered_on_in_provider?
      signal :poll_destination_powered_off_in_provider
    else
      phase_context[:power_on_wait_count] ||= 0
      phase_context[:power_on_wait_count] += 1
      requeue_phase
    end
  end

  def poll_destination_in_vmdb
    update_and_notify_parent(:message => "Validating New #{destination_type}")

    self.destination = find_destination_in_vmdb(phase_context[:new_vm_ems_ref])
    if destination
      phase_context.delete(:new_vm_ems_ref)
      signal :customize_destination
    else
      _log.info("Unable to find #{destination_type} [#{dest_name}] with ems_ref [#{phase_context[:new_vm_ems_ref]}], will retry")
      requeue_phase
    end
  end

  def poll_destination_powered_off_in_vmdb
    update_and_notify_parent(:message => "Waiting for VMDB PowerOff of #{for_destination}")

    if destination.power_state == 'off'
      signal :post_provision
    else
      _log.info("#{destination_type} [#{dest_name}] is not yet powered off, will retry")
      EmsRefresh.queue_refresh(destination)
      requeue_phase
    end
  end

  def post_provision
    signal :autostart_destination
  end

  def autostart_destination
    if get_option(:vm_auto_start)
      message = "Starting"
      _log.info("#{message} #{for_destination}")
      update_and_notify_parent(:message => message)
      destination.start
    end

    signal :post_create_destination
  end

  def post_create_destination
    _log.info("Destination #{destination.class.base_model.name} ID=#{destination.id}, Name=#{destination.name}")

    set_description(destination, get_option(:vm_description))
    set_ownership(destination, get_owner || get_user)
    set_retirement(destination)
    set_genealogy(destination, source)
    set_miq_custom_attributes(destination, get_option(:ws_miq_custom_attributes))
    set_ems_custom_attributes(destination, get_option(:ws_ems_custom_attributes))
    connect_to_service(destination, *get_service_and_service_resource)

    destination.save

    # HACK:
    # apply_tags calls Classification#assign_entry_to for each tag to apply
    # Classification#assign_entry_to reloads the object it is passed (why?)
    # So, we need to apply tags AFTER we save the destination object
    apply_tags(destination)

    signal :mark_as_completed
  end

  def mark_as_completed
    begin
      inputs = {:vm => destination, :host => destination.host}
      MiqEvent.raise_evm_event(destination, 'vm_provisioned', inputs)
    rescue => err
      _log.log_backtrace(err)
    end

    if MiqProvision::AUTOMATE_DRIVES
      update_and_notify_parent(:state => 'provisioned', :message => "Finished New VM Customization")
    else
      update_and_notify_parent(:state => 'finished', :message => "Request #{pass} of #{number_of_vms} is complete")
      call_automate_event('vm_provision_postprocessing')
    end
    signal :finish
  end

  def finish
    mark_execution_servers
    if status != 'Error'
      number_of_vms = get_option(:number_of_vms).to_i
      pass = get_option(:pass)
      _log.info("Executing provision request: [#{description}], Pass: #{pass} of #{number_of_vms}... Complete")
    end
  end

  def clone_direction
    "[#{source.name}] to #{destination_type} [#{dest_name}]"
  end

  def for_destination
    "#{destination_type} id: [#{destination.id}], name: [#{dest_name}]"
  end
end
