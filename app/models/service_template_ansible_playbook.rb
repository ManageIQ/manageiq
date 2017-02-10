class ServiceTemplateAnsiblePlaybook < ServiceTemplateGeneric
  def self.default_provisioning_entry_point(_service_type = nil)
    '/Service/Generic/StateMachines/GenericLifecycle/provision'
  end

  def self.default_retirement_entry_point
    '/Service/Generic/StateMachines/GenericLifecycle/retire'
  end

  # create ServiceTemplate and supporting ServiceResources and ResourceActions
  # options
  #   :name
  #   :description
  #   :service_template_catalog
  #   :config_info
  #     :provision
  #       :service_dialog_id (or)
  #       :new_dialog_name
  #       :variables
  #       :hosts
  #       :cloud_credential_id
  #       :network_credential_id
  #       :credential_id
  #       :playbook_id
  #     :retirement (same as provision)
  #     :reconfigure (same as provision)
  #
  def self.create_catalog_item(options, _auth_user)
    task_id = create_catalog_item_queue(options, _auth_user)
    task = MiqTask.wait_for_taskid(task_id)
    raise task.message unless task.status == "Ok"
    task.task_results
  end

  def self.create_catalog_item_queue(options, auth_user)
    task_opts = {
      :action => "Create Ansible Playbook Service Template",
      :userid => "system"
    }

    playbook = ManageIQ::Providers::AnsibleTower::AutomationManager::Playbook.find(options.fetch_path(:config_info, :provision, :playbook_id))
    tower = playbook.manager

    queue_opts = {
      :args        => [options, auth_user],
      :class_name  => "ServiceTemplateAnsiblePlaybook",
      :method_name => "create_catalog_item_task",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => "ems_operations",
      :zone        => tower.my_zone
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_catalog_item_task(options, _auth_user)
    options      = options.merge(:service_type => 'atomic', :prov_type => 'generic_ansible_playbook')
    service_name = options[:name]
    description  = options[:description]
    config_info  = validate_config_info(options)

    transaction do
      create_from_options(options.except(:task_id)).tap do |service_template|
        [:provision, :retirement, :reconfigure].each do |action|
          prepare_job_template_and_dialog(action, service_name, description, options) if config_info.key?(action)
        end
        service_template.create_resource_actions(config_info)
      end
    end
  end

  def self.prepare_job_template_and_dialog(action, service_name, description, options)
    config_info = options[:config_info]
    job_template = create_job_template("#{options[:task_id]}_#{service_name}_#{action}", description, config_info[action])
    config_info[action][:configuration_template] = job_template

    if config_info[:new_dialog_name]
      config_info[action][:dialog] =
        Dialog::AnsiblePlaybookService.new.create_dialog(config_info[:new_dialog_name], job_template)
    end
  end
  private_class_method :prepare_job_template_and_dialog

  def self.create_job_template(name, description, info)
    tower, params = build_parameter_list(name, description, info)
    ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript.create_in_provider(tower.id, params, true)
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
    }.merge(info.slice(:extra_vars))

    [:credential, :cloud_credential, :network_credential].each do |credential|
      cred_sym = "#{credential}_id".to_sym
      params[credential] = Authentication.find(info[cred_sym]).manager_ref if info[cred_sym]
    end

    [tower, params]
  end
  private_class_method :build_parameter_list

  def self.validate_config_info(options)
    info = options[:config_info]

    info[:provision][:fqname] ||= default_provisioning_entry_point if info.key?(:provision)
    info[:retirement][:fqname] ||= default_retirement_entry_point if info.key?(:retirement)
    info[:reconfigure][:fqname] ||= default_reconfiguration_entry_point if info.key?(:reconfigure)

    # TODO: Add more validation for required fields

    info
  end
  private_class_method :validate_config_info
end
