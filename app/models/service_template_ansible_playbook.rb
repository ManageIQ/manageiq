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
  #       :credentials
  #       :playbook_id
  #     :retirement (same as provision)
  #     :reconfigure (same as provision)
  #
  def self.create_catalog_item(options, _auth_user)
    task_id = create_catalog_item_queue(options)
    task = MiqTask.wait_for_taskid(task_id)
    task.task_results
  end

  def self.create_catalog_item_queue(options)
    task_opts = {
      :action => "Create Ansible Playbook Service Template",
      :userid => "system"
    }

    # This is a lookup for now
    playbook = ManageIQ::Providers::AnsibleTower::AutomationManager::Playbook.find(options[:config_info][:provision][:playbook_id])
    internal_tower = playbook.configuration_script_source.manager

    queue_opts = {
      :args        => [options, _auth_user],
      :class_name  => "ServiceTemplateAnsiblePlaybook",
      :method_name => "create_catalog_item_task",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => "ems_operations",
      :zone        => internal_tower.my_zone
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_catalog_item_task(options, _auth_user)
    options      = options.merge(:service_type => 'atomic', :prov_type => 'generic_ansible_playbook')
    service_name = options[:name]
    description  = options[:description]
    config_info  = validate_config_info(options)

    transaction do
      create(options.except(:config_info, :task_id)).tap do |service_template|
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
    playbook = ManageIQ::Providers::AnsibleTower::AutomationManager::Playbook.find(info[:playbook_id])
    # This is a lookup for now
    internal_tower = playbook.configuration_script_source.manager

    params = {
      :name                     => name,
      :description              => description || '',
      :project                  => playbook.configuration_script_source.manager_ref,
      :playbook                 => playbook.name,
      :inventory                => internal_tower.inventory_root_groups.first.ems_ref,
      :ask_variables_on_launch  => true,
      :ask_limit_on_launch      => true,
      :ask_inventory_on_launch  => true,
      :ask_credential_on_launch => true
    }.merge(info.slice(:extra_vars, :credential, :cloud_credential, :network_credential))
    ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript.create_in_provider(internal_tower.id, params, true)
  end
  private_class_method :create_job_template

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
