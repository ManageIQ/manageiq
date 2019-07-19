class ManageIQ::Providers::AnsiblePlaybookWorkflow < ManageIQ::Providers::AnsibleRunnerWorkflow
  def self.job_options(env_vars, extra_vars, playbook_options, timeout, poll_interval, hosts, credentials, verbosity, become_enabled)
    {
      :become_enabled => become_enabled,
      :credentials    => credentials,
      :env_vars       => env_vars,
      :extra_vars     => extra_vars,
      :hosts          => hosts,
      :playbook_path  => playbook_options[:playbook_path],
      :timeout        => timeout,
      :poll_interval  => poll_interval,
      :verbosity      => verbosity
    }
  end

  def pre_playbook
    # A step before running the playbook for any optional setup tasks
    queue_signal(:run_playbook)
  end

  def run_playbook
    env_vars, extra_vars, playbook_path = options.values_at(:env_vars, :extra_vars, :playbook_path)
    kwargs = options.slice(:credentials, :hosts, :verbosity, :become_enabled)

    response = Ansible::Runner.run_async(env_vars, extra_vars, playbook_path, kwargs)
    if response.nil?
      queue_signal(:abort, "Failed to run ansible playbook", "error")
    else
      context[:ansible_runner_response] = response.dump

      started_on = Time.now.utc
      update_attributes!(:context => context, :started_on => started_on)
      miq_task.update_attributes!(:started_on => started_on)

      queue_signal(:poll_runner)
    end
  end

  def load_transitions
    super.tap do |transactions|
      transactions.merge!(
        :start        => {'waiting_to_start' => 'pre_playbook'},
        :run_playbook => {'pre_playbook'     => 'running'},
      )
    end
  end

  alias start pre_playbook
end
