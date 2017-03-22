class ServiceTemplateAnsiblePlaybook < ServiceTemplateGeneric
  RETIREMENT_ENTRY_POINTS = {
    'yes_without_playbook' => '/Service/Generic/StateMachines/GenericLifecycle/Retire_Basic_Resource',
    'no_without_playbook'  => '/Service/Generic/StateMachines/GenericLifecycle/Retire_Basic_Resource_None',
    'no_with_playbook'     => '/Service/Generic/StateMachines/GenericLifecycle/Retire_Advanced_Resource_None',
    'pre_with_playbook'    => '/Service/Generic/StateMachines/GenericLifecycle/Retire_Advanced_Resource_Pre',
    'post_with_playbook'   => '/Service/Generic/StateMachines/GenericLifecycle/Retire_Advanced_Resource_Post'
  }.freeze
  private_constant :RETIREMENT_ENTRY_POINTS

  def self.default_provisioning_entry_point(_service_type)
    '/Service/Generic/StateMachines/GenericLifecycle/provision'
  end

  def self.default_retirement_entry_point
    RETIREMENT_ENTRY_POINTS['yes_without_playbook']
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

          new_dialog = service_template.send(:create_new_dialog, dialog_name, job_template)
          enhanced_config[action][:dialog] = new_dialog
          service_template.options[:config_info][action][:dialog_id] = new_dialog.id
        end
        service_template.create_resource_actions(enhanced_config)
      end
    end
  end

  def create_new_dialog(dialog_name, job_template)
    Dialog::AnsiblePlaybookServiceDialog.create_dialog(dialog_name, job_template)
  end
  private :create_new_dialog

  def self.create_job_templates(service_name, description, config_info, auth_user)
    [:provision, :retirement, :reconfigure].each_with_object({}) do |action, hash|
      next unless config_info[action] && config_info[action].key?(:playbook_id)
      hash[action] = { :configuration_template => create_job_template("miq_#{service_name}_#{action}", description, config_info[action], auth_user) }
    end
  end
  private_class_method :create_job_templates

  def self.create_job_template(name, description, info, auth_user)
    tower, params = build_parameter_list(name, description, info)

    task_id = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript.create_in_provider_queue(tower.id, params, auth_user)
    task = MiqTask.wait_for_taskid(task_id)
    raise task.message unless task.status == "Ok"
    task.task_results
  end
  private_class_method :create_job_template

  def self.build_parameter_list(name, description, info)
    playbook = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook.find(info[:playbook_id])
    tower = playbook.manager
    params = {
      :name                     => name,
      :description              => description || '',
      :project                  => playbook.configuration_script_source.manager_ref,
      :playbook                 => playbook.name,
      :inventory                => tower.inventory_root_groups.find_by!(:name => 'Demo Inventory').ems_ref,
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
    info[:provision][:fqname]   ||= default_provisioning_entry_point('atomic') if info.key?(:provision)
    info[:reconfigure][:fqname] ||= default_reconfiguration_entry_point if info.key?(:reconfigure)

    if info.key?(:retirement)
      info[:retirement][:fqname] ||= RETIREMENT_ENTRY_POINTS[info[:retirement][:remove_resources]]
      info[:retirement][:fqname] ||= default_retirement_entry_point
    else
      info[:retirement] = {:fqname => default_retirement_entry_point}
    end

    # TODO: Add more validation for required fields

    info
  end
  private_class_method :validate_config_info

  def job_template(action)
    resource_actions.find_by!(:action => action.to_s.capitalize).configuration_template
  end

  def update_catalog_item(options, auth_user = nil)
    config_info = validate_update_config_info(options)
    name = options[:name]
    description = options[:description]
    [:provision, :retirement, :reconfigure].each do |action|
      next unless config_info[action]
      info = config_info[action]

      new_dialog = create_new_dialog(info[:new_dialog_name], job_template(action)) if info[:new_dialog_name]
      info[:dialog_id] = new_dialog.id if new_dialog
      update_for_new_template(info, action, name, description, auth_user)

      next unless info.key?(:playbook_id)
      tower, params = self.class.send(:build_parameter_list, "miq_#{name}_#{action}", description, info)
      params[:manager_ref] = job_template(action).manager_ref
      ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript.update_in_provider_queue(tower.id, params, auth_user)
    end
    super
  end

  def validate_update_config_info(options)
    opts = super
    self.class.send(:validate_config_info, opts)
  end

  def create_job_templates(name, description, config_info, auth_user)
    self.class.send(:create_job_templates, name, description, config_info, auth_user)
  end
  private :create_job_templates

  def update_for_new_template(info, action, name, description, auth_user)
    return unless job_template(action).nil? && info.key?(:playbook_id)
    single_config = { action => info }
    config_template = single_config.deep_merge(create_job_templates(name, description, single_config, auth_user))
    transaction do
      job_template = config_template.fetch_path(action, :configuration_template)
      new_dialog = create_new_dialog(info[:new_dialog_name], job_template) if info[:new_dialog_name]
      updatable_resources = {
        :configuration_template_id   => job_template.id,
        :configuration_template_type => 'ConfigurationScriptBase',
      }
      updatable_resources[:dialog_id] = new_dialog.id if new_dialog
      resource_actions
        .find_by!(:action => action.to_s.capitalize)
        .update_attributes!(updatable_resources)
    end
  end
  private :update_for_new_template
end
