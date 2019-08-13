class ServiceAnsiblePlaybook < ServiceGeneric
  include AnsibleExtraVarsMixin

  delegate :job_template, :to => :service_template, :allow_nil => true

  # A chance for taking options from automate script to override options from a service dialog
  def preprocess(action, add_options = {})
    if add_options.present?
      _log.info("Override with new options:")
      $log.log_hashes(add_options)
    end

    save_job_options(action, add_options)
  end

  def execute(action)
    launch_ansible_job_queue(action)
  end

  def launch_ansible_job_queue(action)
    task_opts = {
      :action => "Launching Ansible Job",
      :userid => "system"
    }

    queue_opts = {
      :args        => [action],
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "launch_ansible_job",
      :role        => "embedded_ansible"
    }

    task_id = MiqTask.generic_action_with_callback(task_opts, queue_opts)
    task = MiqTask.wait_for_taskid(task_id)
    raise task.message unless task.status_ok?
  end

  def launch_ansible_job(action)
    jt = job_template(action)
    opts = get_job_options(action).deep_merge(
      :extra_vars => {
        'manageiq'            => service_manageiq_env(action),
        'manageiq_connection' => manageiq_connection_env(evm_owner)
      }
    )
    opts[:hosts] = hosts_array(opts.delete(:hosts))

    _log.info("Launching Ansible job with options:")
    $log.log_hashes(opts, :filter => ["api_token", "token"])
    new_job = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job.create_job(jt, decrypt_options(opts))
    update_job_for_playbook(action, new_job, opts[:hosts])

    _log.info("Ansible job with ref #{new_job.ems_ref} was created.")
    add_resource!(new_job, :name => action)
  end

  def check_completed(action)
    status, reason = job(action).raw_status.normalized_status
    done    = status != 'transient'
    message = status == 'create_complete' ? nil : reason
    [done, message]
  rescue MiqException::MiqOrchestrationStackNotExistError, MiqException::MiqOrchestrationStatusError => err
    [true, err.message] # consider done with an error when exception is caught
  end

  def refresh(action)
    job(action).refresh_ems
  end

  def check_refreshed(_action)
    [true, nil]
  end

  def job(action)
    service_resources.find_by(:name => action, :resource_type => 'OrchestrationStack').try(:resource)
  end

  def postprocess(action)
    log_stdout(action)
  end

  def on_error(action)
    _log.info("on_error called for service action: #{action}")
    update_attributes(:retirement_state => 'error') if action == "Retirement"
    job(action).try(:refresh_ems)
    postprocess(action)
  end

  def retain_resources_on_retirement?
    options.fetch_path(:config_info, :retirement, :remove_resources).to_s.start_with?("no_")
  end

  private

  def service_manageiq_env(action)
    {
      'service' => href_slug,
      'action'  => action
    }.merge(manageiq_env(evm_owner, miq_group, miq_request_task))
      .merge(request_options_extra_vars)
  end

  def request_options_extra_vars
    miq_request_task.options.fetch_path(:request_options, :manageiq_extra_vars) || {}
  end

  def get_job_options(action)
    options[job_option_key(action)].deep_dup
  end

  CONFIG_OPTIONS_WHITELIST = %i[
    become_enabled
    cloud_credential_id
    credential_id
    execution_ttl
    extra_vars
    hosts
    network_credential_id
    vault_credential_id
    verbosity
  ].freeze

  def config_options(action)
    options.fetch_path(:config_info, action.downcase.to_sym).slice(*CONFIG_OPTIONS_WHITELIST).with_indifferent_access
  end

  def translate_credentials!(job_options)
    %i[credential vault_credential network_credential cloud_credential].each do |cred|
      cred_sym = "#{cred}_id".to_sym
      credential_id = job_options.delete(cred_sym)
      job_options[cred] = Authentication.find(credential_id).native_ref if credential_id.present?
    end
  end

  def save_job_options(action, overrides)
    job_options = config_options(action)

    job_options[:extra_vars].try(:transform_values!) do |val|
      val.kind_of?(String) ? val : val[:default] # TODO: support Hash only
    end

    job_options.deep_merge!(parse_dialog_options) unless action == ResourceAction::RETIREMENT
    job_options.deep_merge!(overrides)
    translate_credentials!(job_options)

    options[job_option_key(action)] = job_options
    save!
  end

  def job_option_key(action)
    "#{action.downcase}_job_options".to_sym
  end

  def parse_dialog_options
    dialog_options = options[:dialog] || {}

    {
      :credential_id => dialog_options['dialog_credential'],
      :hosts         => dialog_options['dialog_hosts'].to_s.strip.presence
    }.compact.merge(extra_vars_from_dialog)
  end

  def extra_vars_from_dialog
    params =
      (options[:dialog] || {}).each_with_object({}) do |(attr, val), obj|
        var_key = attr.sub(/^(password::)?dialog_param_/, '')
        obj[var_key] = val unless var_key == attr
      end

    params.blank? ? {} : {:extra_vars => params}
  end

  def use_default_inventory?(hosts)
    hosts.blank? || hosts == 'localhost'
  end

  def hosts_array(hosts_string)
    return ["localhost"] if use_default_inventory?(hosts_string)

    hosts_string.split(',').map(&:strip).delete_blanks
  end

  # update job attributes only available to playbook provisioning
  def update_job_for_playbook(action, job, hosts)
    playbook_id = options.fetch_path(:config_info, action.downcase.to_sym, :playbook_id)
    job.update!(:configuration_script_base_id => playbook_id, :hosts => hosts)
  end

  def decrypt_options(opts)
    opts.tap do
      opts[:extra_vars].transform_values! { |val| val.kind_of?(String) ? ManageIQ::Password.try_decrypt(val) : val }
    end
  end

  def log_stdout(action)
    log_option = options.fetch_path(:config_info, action.downcase.to_sym, :log_output) || 'on_error'
    return unless %(on_error always).include?(log_option)
    job = job(action)
    return if log_option == 'on_error' && job.raw_status.succeeded?
    _log.info("Stdout from ansible job #{job.name}: #{job.raw_stdout('txt_download')}")
  rescue => err
    _log.error("Failed to get stdout from ansible job #{job.name}")
    _log.log_backtrace(err)
  end
end
