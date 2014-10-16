module MiqProvision::StateMachine
  def run_provision
    self.source = get_source  # just in case automate changed src_vm_id in the options hash
    signal :create_destination
  end

  def create_destination
    raise NotImplementedError, "Must be implemented in subclass and signal :post_create_destination when self.destination is set"
  end

  def prepare_provision
    update_and_notify_parent(:message => "Preparing to Clone #{clone_direction}")
    self.phase_context[:clone_options] = prepare_for_clone_task

    signal :start_clone_task
  end

  def poll_destination_in_vmdb
    update_and_notify_parent(:message => "Validating New #{destination_type}")

    self.destination = find_destination_in_vmdb(self.phase_context[:new_vm_ems_ref])
    if self.destination
      self.phase_context.delete(:new_vm_ems_ref)
      signal :customize_destination
    else
      $log.info("MIQ(#{self.class.name}#poll_destination_in_vmdb) Unable to find #{destination_type} [#{dest_name}] with ems_ref [#{self.phase_context[:new_vm_ems_ref]}], will retry")
      requeue_phase
    end
  end

  def poll_destination_powered_off_in_vmdb
    update_and_notify_parent(:message => "Waiting for PowerOff #{for_destination}")

    if self.destination.power_state == 'off'
      signal :post_provision
    else
      $log.info("MIQ(#{self.class.name}#poll_destination_powered_off_in_vmdb) #{destination_type} [#{dest_name}] is not yet powered off, will retry")
      EmsRefresh.queue_refresh(self.destination)
      requeue_phase
    end
  end

  def post_provision
    signal :autostart_destination
  end

  def autostart_destination
    if get_option(:vm_auto_start)
      message = "Starting"
      $log.info("MIQ(#{self.class.name}#autostart_destination) #{message} #{for_destination}")
      update_and_notify_parent(:message => message)
      self.destination.start
    end

    signal :post_create_destination
  end

  def post_create_destination
    log_header = "MIQ(#{self.class.name}#post_create_destination)"

    $log.info "#{log_header} Destination #{self.destination.class.base_model.name} ID=#{self.destination.id}, Name=#{self.destination.name}"

    set_description(self.destination, get_option(:vm_description))
    set_ownership(self.destination, get_user_by_email)
    set_retirement(self.destination)
    set_genealogy(self.destination, self.source)
    set_miq_custom_attributes(self.destination, get_option(:ws_miq_custom_attributes))
    set_ems_custom_attributes(self.destination, get_option(:ws_ems_custom_attributes))
    connect_to_service(self.destination, *self.get_service_and_service_resource)

    self.destination.save

    # HACK:
    # apply_tags calls Classification#assign_entry_to for each tag to apply
    # Classification#assign_entry_to reloads the object it is passed (why?)
    # So, we need to apply tags AFTER we save the destination object
    apply_tags(self.destination)

    signal :mark_as_completed
  end

  def mark_as_completed
    begin
      inputs = {:vm => self.destination, :host => self.destination.host}
      MiqEvent.raise_evm_event(self.destination, 'vm_provisioned', inputs)
    rescue => err
      $log.log_backtrace(err)
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
    if self.status != 'Error'
      number_of_vms = get_option(:number_of_vms).to_i
      pass = get_option(:pass)
      $log.info("MIQ(#{self.class.name}#finish) Executing provision request: [#{self.description}], Pass: #{pass} of #{number_of_vms}... Complete")
    end
  end

end
