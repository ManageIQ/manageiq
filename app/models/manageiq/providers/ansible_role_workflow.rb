class ManageIQ::Providers::AnsibleRoleWorkflow < ManageIQ::Providers::AnsibleRunnerWorkflow
  def execution_type
    "role"
  end

  def launch_runner
    env_vars, extra_vars, role_name, roles_path, role_skip_facts = options.values_at(:env_vars, :extra_vars, :role_name, :roles_path, :role_skip_facts)
    role_skip_facts = true if role_skip_facts.nil?

    Ansible::Runner.run_role_async(env_vars, extra_vars, role_name, :roles_path => roles_path, :role_skip_facts => role_skip_facts)
  end

  private

  def verify_options
    unless options[:role_name]
      raise ArgumentError, "must pass :role_name"
    end

    if !!options[:configuration_script_source_id] ^ !!options[:roles_relative_path]
      raise ArgumentError, "cannot pass half of a :configuration_script_source_id, :roles_relative_path pair"
    end
  end

  def adjust_options_for_git_checkout_tempdir!
    options[:roles_path] = File.join(options[:git_checkout_tempdir], options[:roles_relative_path])
    save!
  end
end
