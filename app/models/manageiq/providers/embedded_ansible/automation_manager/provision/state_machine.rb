module ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Provision::StateMachine
  def run_provision
    signal :provision
  end

  def provision
    opts = %i[become_enabled cloud_credential_id credential_id execution_ttl extra_vars hosts network_credential_id vault_credential_id verbosity].to_h do |key|
      [key, get_option(key)]
    end

    opts[:hosts] ||= %w[localhost]
    stack = stack_klass.create_stack(source.parent, opts)

    phase_context[:stack_id] = stack.id
    connect_to_service!(stack, :name => "Provision")

    save!

    signal :check_provisioned
  end

  def check_provisioned
    if running?
      requeue_phase
    else
      signal :post_provision
    end
  end

  def post_provision
    if succeeded?
      signal :mark_as_completed
    else
      abort_job("Failed to provision playbook", "error")
    end
  end

  def running?
    !stack.raw_status.completed?
  end

  def succeeded?
    stack.raw_status.succeeded?
  end

  def mark_as_completed
    update_and_notify_parent(:state => "finished", :message => "Playbook provision is complete")
    signal :finish
  end

  def finish
    mark_execution_servers
  end

  def stack_klass
    ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job
  end

  def stack
    @stack ||= stack_klass.find(phase_context[:stack_id])
  end
end
