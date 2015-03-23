require 'manageiq_foreman'
module MiqProvisionTaskConfiguredSystemForeman::StateMachine
  def run_provision
    validate_source
    signal :prepare_provision
  end

  def prepare_provision
    prepare_provider_options
    merge_provider_options_from_automate
    signal :start_configuration_task
  end

  def start_configuration_task
    update_and_notify_parent(:message => "Starting configuration of #{source.name}")
    log_provider_options
    signal :system_power_off_in_foreman
  end

  def system_power_off_in_foreman
    update_and_notify_parent(:message => "Powering off #{source.name}")
    source.provider_object.stop
    signal :poll_system_powered_off_in_foreman
  end

  def poll_system_powered_off_in_foreman
    update_and_notify_parent(:message => "Waiting for power off of #{source.name}")
    if source.provider_object.powered_off?
      signal :update_configuration
    else
      requeue_phase
    end
  end

  def update_configuration
    update_and_notify_parent(:message => "Updating configuration of #{source.name}")
    source.with_provider_object { |cs| cs.update(phase_context[:provider_options]) }
    signal :enable_build_mode
  end

  def enable_build_mode
    update_and_notify_parent(:message => "Setting build flag on #{source.name}")
    source.with_provider_object { |cs| cs.update("id" => source.manager_ref, "build" => true) }
    signal :os_build
  end

  def os_build
    update_and_notify_parent(:message => "Building OS on #{source.name}")
    if source.with_provider_object(&:powered_on?)
      signal :poll_os_built
    else
      source.with_provider_object(&:reboot)
      requeue_phase
    end
  end

  def poll_os_built
    update_and_notify_parent(:message => "Waiting for OS build on #{source.name}")
    if source.provider_object.building?
      requeue_phase
    else
      signal :mark_as_completed
    end
  end

  def mark_as_completed
    begin
      MiqEvent.raise_evm_event(source, 'configured_system_provisioned', :configured_system => source)
    rescue => err
      $log.log_backtrace(err)
    end

    update_and_notify_parent(:state => 'provisioned', :message => "Finished Configured System Customization")
    signal :finish
  end

  def finish
    if status != 'Error'
      $log.info("MIQ(#{self.class.name}##{__method__}) Executing provision request: [#{description}]... Complete")
    end
  end
end
