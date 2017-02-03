class ServiceAnsiblePlaybook < ServiceGeneric
  # A chance for taking options from automate script to override options from a service dialog
  def preprocess(action, add_options = {})
    save_job_options(action, add_options)
  end

  def execute(action)
    jt = job_template(action)
    opts = get_job_options(action)

    _log.info("Launching Ansible Tower job with options: #{opts}")
    new_job = ManageIQ::Providers::AnsibleTower::AutomationManager::Job.create_job(jt, opts)

    _log.info("Ansible Tower job with ref #{new_job.ems_ref} was created.")
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
    service_resources.find_by!(:name => action, :resource_type => 'OrchestrationStack').try(:resource)
  end

  private

  def job_template(action)
    service_template.resource_actions.find_by!(:action => action).configuration_template
  end

  def get_job_options(action)
    job_opts = options["#{action.downcase}_job_options".to_sym].deep_dup
    credential_id = job_opts.delete(:credential_id)
    job_opts[:credential] = Authentication.find(credential_id).manager_ref unless credential_id.blank?

    job_opts
  end

  def save_job_options(action, overrides)
    job_options = parse_dialog_options
    job_options[:extra_vars] = (job_options[:extra_vars] || {}).merge(overrides[:extra_vars]) if overrides[:extra_vars]
    job_options.merge!(overrides.except(:extra_vars))

    options["#{action.downcase}_job_options".to_sym] = job_options
    save!
  end

  def parse_dialog_options
    dialog_options = options[:dialog] || {}
    {
      :credential_id => dialog_options['dialog_credential_id'],
      :hosts         => dialog_options['dialog_hosts']
    }.compact.merge(extra_vars_from_dialog)
  end

  def extra_vars_from_dialog
    params =
      (options[:dialog] || {}).each_with_object({}) do |(attr, val), obj|
        obj[attr.sub('dialog_param_', '')] = val if attr =~ /dialog_param_/
      end

    params.blank? ? {} : {:extra_vars => params}
  end
end
