class ManageIQ::Providers::AnsibleRoleWorkflow < ManageIQ::Providers::AnsibleRunnerWorkflow
  def execution_type
    "role"
  end

  def launch_runner
    env_vars, extra_vars, role_name, roles_path, role_skip_facts = options.values_at(:env_vars, :extra_vars, :role_name, :roles_path, :role_skip_facts)
    role_skip_facts = true if role_skip_facts.nil?

    Ansible::Runner.run_role_async(env_vars, extra_vars, role_name, :roles_path => roles_path, :role_skip_facts => role_skip_facts)
  end
end
