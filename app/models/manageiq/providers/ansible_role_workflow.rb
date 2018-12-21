class ManageIQ::Providers::AnsibleRoleWorkflow < ManageIQ::Providers::AnsibleRunnerWorkflow
  def self.job_options(env_vars, extra_vars, role_options, timeout, poll_interval)
    {
      :env_vars        => env_vars,
      :extra_vars      => extra_vars,
      :role_name       => role_options[:role_name],
      :roles_path      => role_options[:roles_path],
      :role_skip_facts => role_options[:role_skip_facts],
      :timeout         => timeout,
      :poll_interval   => poll_interval
    }
  end

  def pre_role
    # A step before running the playbook for any optional setup tasks
    queue_signal(:run_role)
  end

  def run_role
    env_vars, extra_vars, role_name, roles_path, role_skip_facts = options.values_at(:env_vars, :extra_vars, :role_name, :roles_path, :role_skip_facts)
    role_skip_facts = true if role_skip_facts.nil?
    response = Ansible::Runner.run_role_async(env_vars, extra_vars, role_name, :roles_path => roles_path, :role_skip_facts => role_skip_facts)
    if response.nil?
      queue_signal(:abort, "Failed to run ansible role", "error")
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
        :start    => {'waiting_to_start' => 'pre_role'},
        :run_role => {'pre_role'         => 'running' },
      )
    end
  end

  alias start pre_role
end
