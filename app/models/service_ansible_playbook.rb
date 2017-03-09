class ServiceAnsiblePlaybook < ServiceGeneric
  delegate :job_template, :to => :service_template, :allow_nil => true

  # A chance for taking options from automate script to override options from a service dialog
  def preprocess(action, add_options = {})
    _log.info("Override with new options: #{add_options}") unless add_options.blank?
    save_job_options(action, add_options)
  end

  def execute(action)
    jt = job_template(action)
    opts = get_job_options(action)

    _log.info("Launching Ansible Tower job with options: #{opts}")
    new_job = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job.create_job(jt, opts)
    update_job_for_playbook(action, new_job, opts[:hosts])

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
    service_resources.find_by(:name => action, :resource_type => 'OrchestrationStack').try(:resource)
  end

  def postprocess(action)
    hosts = options.fetch_path(job_option_key(action), :inventory)
    delete_inventory(action) unless use_default_inventory?(hosts)
  end

  private

  def get_job_options(action)
    job_opts = options[job_option_key(action)].deep_dup

    # TODO: decryption may be needed
    job_opts
  end

  def save_job_options(action, overrides)
    job_options = options.fetch_path(:config_info, action.downcase.to_sym).slice(:hosts, :extra_vars)
    job_options.deep_merge!(parse_dialog_options)
    job_options.deep_merge!(overrides)

    credential_id = job_options.delete(:credential_id)
    job_options[:credential] = Authentication.find(credential_id).manager_ref unless credential_id.blank?

    hosts = job_options.delete(:hosts)
    job_options[:inventory] = create_inventory_with_hosts(action, hosts).id unless use_default_inventory?(hosts)

    # TODO: encryption my be needed
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
        obj[attr.sub('dialog_param_', '')] = val if attr =~ /dialog_param_/
      end

    params.blank? ? {} : {:extra_vars => params}
  end

  def create_inventory_with_hosts(action, hosts)
    manager(action).with_provider_connection do |connection|
      connection.api.inventories.create!(:name => inventory_name(action), :organization => 1).tap do |inventory|
        hosts.split(',').each do |host|
          connection.api.hosts.create!(:name => host, :inventory => inventory.id)
        end
      end
    end
  end

  def delete_inventory(action)
    manager(action).with_provider_connection do |connection|
      inventory_id = options.fetch_path(job_option_key(action), :inventory)
      connection.api.inventories.find(inventory_id).destroy!
    end
  end

  def manager(action)
    job_template(action).manager
  end

  def inventory_name(action)
    "#{job_template(action).name}_#{id}"
  end

  def use_default_inventory?(hosts)
    hosts.blank? || hosts == 'localhost'
  end

  # update job attributes only available to playbook provisioning
  def update_job_for_playbook(action, job, hosts)
    hosts = (hosts || 'localhost').split(',')
    playbook_id = options.fetch_path(:config_info, action.downcase.to_sym, :playbook_id)
    job.update_attributes(:configuration_script_base_id => playbook_id, :hosts => hosts)
  end
end
