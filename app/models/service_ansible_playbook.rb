class ServiceAnsiblePlaybook < ServiceGeneric
  include AnsibleExtraVarsMixin
  include AnsiblePlaybookMixin

  delegate :playbook, :repository, :to => :service_template, :allow_nil => true

  def my_zone
    miq_request&.my_zone
  end

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

  def check_connection(action)
    repository(action).check_connection?
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
      :role        => "embedded_ansible",
      :zone        => my_zone
    }

    task_id = MiqTask.generic_action_with_callback(task_opts, queue_opts)
    task = MiqTask.wait_for_taskid(task_id)
    raise task.message unless task.status_ok?
  end

  def launch_ansible_job(action)
    my_playbook = playbook(action)
    opts = get_job_options(action).deep_merge(
      :extra_vars => {
        'manageiq'            => service_manageiq_env(action),
        'manageiq_connection' => manageiq_connection_env(evm_owner)
      }
    )
    opts[:hosts] = hosts_array(opts.delete(:hosts))

    if opts[:execution_ttl].blank?
      opts[:execution_ttl] = options[automate_timeout_key(action)]
      _log.info("execution_ttl is set to automate timeout [#{opts[:execution_ttl]}] minutes")
    end

    _log.info("Launching Ansible job with options:")
    $log.log_hashes(opts, :filter => ["api_token", "token"])
    new_job = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job.create_job(my_playbook, decrypt_options(opts))
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
    update(:retirement_state => 'error') if action == "Retirement"
    if job(action)
      job(action).try(:refresh_ems)
      postprocess(action)
    else
      _log.info("postprocess not called because job was nil")
    end
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

  def config_options(action)
    options.fetch_path(:config_info, action.downcase.to_sym).slice(*CONFIG_OPTIONS_WHITELIST).with_indifferent_access
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
    job = job(action)
    if job.nil?
      $log.info("No stdout available due to missing job")
    else
      playbook_log_stdout(log_option, job)
    end
  end
end
