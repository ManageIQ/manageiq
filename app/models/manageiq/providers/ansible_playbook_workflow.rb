class ManageIQ::Providers::AnsiblePlaybookWorkflow < ManageIQ::Providers::AnsibleRunnerWorkflow
  def execution_type
    "playbook"
  end

  def launch_runner
    env_vars, extra_vars, playbook_path = options.values_at(:env_vars, :extra_vars, :playbook_path)
    kwargs = options.slice(:credentials, :hosts, :verbosity, :become_enabled)

    Ansible::Runner.run_async(env_vars, extra_vars, playbook_path, kwargs)
  end
end
