require 'manageiq_foreman'
module MiqProvisionTaskConfiguredSystemForeman::StateMachine
  def start_clone_task
    log_clone_options(options)
  end

  def run_provision
    source.with_provider_object { |p| p.update(options) }
    signal build? ? :power_off : :provision_complete
  end

  def power_off
    source.with_provider_object(&:stop)
    signal :poll_powered_off
  end

  def poll_powered_off
    if powered_off?
      signal :boot_source
    else
      requeue_phase
    end
  end

  def boot_source
    source.with_provider_object(&:start)
    signal :poll_build_complete
  end

  def poll_build_complete
    refresh # actively queue a refresh, is this ok?
    if building?
      requeue_phase
    else
      signal :provision_complete
    end
  end

  def provision_complete
    refresh # actively queue a refresh, ok?
  end

  private

  # provisioning builds the box
  # vs alternative that just sets the attributes and doesn't rebuild
  def build?
    options.key?(:build) ? options[:build] : true
  end
end
