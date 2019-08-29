class ManageIQ::Providers::AnsiblePlaybookWorkflow < ManageIQ::Providers::AnsibleRunnerWorkflow
  def self.create_job(*args, **kwargs)
    role_or_playbook_options = args[2]
    args[2] = role_or_playbook_options.merge(:role => "embedded_ansible")
    super(*args, **kwargs)
  end

  def execution_type
    "playbook"
  end

  def launch_runner
    env_vars, extra_vars, playbook_path = options.values_at(:env_vars, :extra_vars, :playbook_path)
    kwargs = options.slice(:credentials, :hosts, :verbosity, :become_enabled)

    Ansible::Runner.run_async(env_vars, extra_vars, playbook_path, kwargs)
  end

  private

  def verify_options
    if !options[:playbook_path] && !(options[:configuration_script_source_id] && options[:playbook_relative_path])
      raise ArgumentError, "must pass :playbook_path or a :configuration_script_source_id, :playbook_relative_path pair"
    end
  end

  def adjust_options_for_git_checkout_tempdir!
    options[:playbook_path] = File.join(options[:git_checkout_tempdir], options[:playbook_relative_path])
    save!
  end
end
