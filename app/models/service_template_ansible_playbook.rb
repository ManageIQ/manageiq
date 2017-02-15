class ServiceTemplateAnsiblePlaybook < ServiceTemplateGeneric
  def self.default_provisioning_entry_point(_service_type)
    '/Service/Generic/StateMachines/GenericLifecycle/provision'
  end

  def self.default_retirement_entry_point
    '/Service/Generic/StateMachines/GenericLifecycle/retire'
  end

  def job_template(action)
    resource_actions.find_by!(:action => action).configuration_template
  end

  # create ServiceTemplate and supporting ServiceResources and ResourceActions
  # options
  #   :name
  #   :description
  #   :service_template_catalog_id
  #   :config_info
  #     :provision
  #       :service_dialog_id (or)
  #       :new_dialog_name
  #       :variables
  #       :hosts
  #       :credential_id
  #       :network_credential_id
  #       :cloud_credential_id
  #       :playbook_id
  #     :retirement (same as provision)
  #     :reconfigure (same as provision)
  #
  def self.create_catalog_item(options, auth_user)
    options      = options.merge(:service_type => 'atomic', :prov_type => 'generic_ansible_playbook')
    service_name = options[:name]
    description  = options[:description]
    config_info  = validate_config_info(options[:config_info])

    enhanced_config = config_info.deep_merge(create_job_templates(service_name, description, config_info, auth_user))

    transaction do
      create_from_options(options).tap do |service_template|
        [:provision, :retirement, :reconfigure].each do |action|
          dialog_name = config_info.fetch_path(action, :new_dialog_name)
          next unless dialog_name

          job_template = enhanced_config.fetch_path(action, :configuration_template)
          enhanced_config[action][:dialog] =
            Dialog::AnsiblePlaybookServiceDialog.create_dialog(dialog_name, job_template)
        end
        service_template.create_resource_actions(enhanced_config)
      end
    end
  end

  def self.prepare_job_template_and_dialog(action, service_name, description, config_info)
    job_template = create_job_template("#{service_name}_#{action}", description, config_info[action])
    config_info[action][:configuration_template] = job_template

    if config_info[:new_dialog_name]
      config_info[action][:dialog] =
        Dialog::AnsiblePlaybookService.new.create_dialog(config_info[:new_dialog_name], job_template)
    end
  end
  private_class_method :prepare_job_template_and_dialog

  def self.create_job_templates(service_name, description, config_info, auth_user)
    [:provision, :retirement, :reconfigure].each_with_object({}) do |action, hash|
      next unless config_info[action]
      hash[action] = { :configuration_template => create_job_template("miq_#{service_name}_#{action}", description, config_info[action], auth_user) }
    end
  end
  private_class_method :create_job_templates

  def self.create_job_template(name, description, info, auth_user)
    tower, params = build_parameter_list(name, description, info)

    task_id = ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript.create_in_provider_queue(tower.id, params, auth_user)
    task = MiqTask.wait_for_taskid(task_id)
    raise task.message unless task.status == "Ok"
    task.task_results
  end
  private_class_method :create_job_template

  def self.build_parameter_list(name, description, info)
    playbook = ManageIQ::Providers::AnsibleTower::AutomationManager::Playbook.find(info[:playbook_id])
    tower = playbook.manager
    params = {
      :name                     => name,
      :description              => description || '',
      :project                  => playbook.configuration_script_source.manager_ref,
      :playbook                 => playbook.name,
      :inventory                => tower.inventory_root_groups.first.ems_ref,
      :ask_variables_on_launch  => true,
      :ask_limit_on_launch      => true,
      :ask_inventory_on_launch  => true,
      :ask_credential_on_launch => true
    }
    params[:extra_vars] = info[:extra_vars].to_json if info[:extra_vars]

    [:credential, :cloud_credential, :network_credential].each do |credential|
      cred_sym = "#{credential}_id".to_sym
      params[credential] = Authentication.find(info[cred_sym]).manager_ref if info[cred_sym]
    end

    [tower, params.compact]
  end
  private_class_method :build_parameter_list

  def self.validate_config_info(info)
    info[:provision][:fqname] ||= default_provisioning_entry_point('atomic') if info.key?(:provision)
    info[:retirement][:fqname] ||= default_retirement_entry_point if info.key?(:retirement)
    info[:reconfigure][:fqname] ||= default_reconfiguration_entry_point if info.key?(:reconfigure)

    # TODO: Add more validation for required fields

    info
  end
  private_class_method :validate_config_info
end
