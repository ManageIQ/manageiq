class ServiceTemplateAnsiblePlaybook < ServiceTemplateGeneric
  before_destroy :check_retirement_potential, :prepend => true
  around_destroy :around_destroy_callback, :prepend => true

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
    options      = options.merge(:service_type => SERVICE_TYPE_ATOMIC, :prov_type => 'generic_ansible_playbook')
    service_name = options[:name]
    description  = options[:description]
    config_info  = validate_config_info(options[:config_info])

    enhanced_config = config_info.deep_merge(create_job_templates(service_name, description, config_info, auth_user))

    transaction do
      create_from_options(options).tap do |service_template|
        dialog_ids = service_template.send(:create_dialogs, enhanced_config)
        enhanced_config.deep_merge!(dialog_ids)
        service_template.options[:config_info].deep_merge!(dialog_ids)
        service_template.create_resource_actions(enhanced_config)
      end
    end
  end

  def create_new_dialog(dialog_name, extra_vars, hosts)
    Dialog::AnsiblePlaybookServiceDialog.create_dialog(dialog_name, extra_vars, hosts)
  end
  private :create_new_dialog

  def self.create_job_templates(service_name, description, config_info, auth_user, service_template = nil)
    [:provision, :retirement, :reconfigure].each_with_object({}) do |action, hash|
      next unless new_job_template_required?(config_info[action], action, service_template)
      hash[action] = { :configuration_template => create_job_template(build_name(service_name, action), description, config_info[action], auth_user) }
    end
  end
  private_class_method :create_job_templates

  def self.build_name(basic_name, action)
    "miq_#{basic_name}_#{action}"
  end
  private_class_method :build_name

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
      :inventory                => tower.provider.default_inventory,
      :become_enabled           => info[:become_enabled].present?,
      :verbosity                => info[:verbosity].presence || 0,
      :ask_variables_on_launch  => true,
      :ask_limit_on_launch      => true,
      :ask_inventory_on_launch  => true,
      :ask_credential_on_launch => true
    }
    if info[:extra_vars]
      params[:extra_vars] = info[:extra_vars].transform_values do |val|
        val.kind_of?(String) ? val : val[:default] # TODO: support Hash only
      end.to_json
    end

    %i(credential vault_credential cloud_credential network_credential).each do |credential|
      cred_sym = "#{credential}_id".to_sym
      params[credential] = Authentication.find(info[cred_sym]).native_ref if info[cred_sym]
    end

    [tower, params.compact]
  end
  private_class_method :build_parameter_list

  def self.validate_config_info(info)
    info[:provision][:fqname]   ||= default_provisioning_entry_point(SERVICE_TYPE_ATOMIC) if info.key?(:provision)
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
    resource_actions.find_by(:action => action.capitalize).try(:configuration_template)
  end

  def update_catalog_item(options, auth_user = nil)
    config_info = validate_update_config_info(options)
    name = options[:name] || self.name
    description = options[:description] || self.description

    update_job_templates(name, description, config_info, auth_user)

    config_info.deep_merge!(self.class.send(:create_job_templates, name, description, config_info, auth_user, self))

    [:provision, :retirement, :reconfigure].each do |action|
      next unless config_info.key?(action)
      config_info[action][:configuration_template] ||= job_template(action)
    end
    config_info.deep_merge!(create_dialogs(config_info))

    options[:config_info] = config_info

    super
  end

  # ServiceTemplate includes a retirement resource action
  #   with a defined job template:
  #
  #   1. A resource_action that includes a configuration_template_id.
  #   2. At least one service instance where :retired is set to false.
  #
  def retirement_potential?
    retirement_jt_exists = resource_actions.where(:action => 'Retirement').where.not(:configuration_template_id => nil).present?
    retirement_jt_exists && services.where(:retired => false).exists?
  end

  private

  def around_destroy_callback
    job_templates = resource_actions.where.not(:configuration_template_id => nil).collect(&:configuration_template)
    yield
    delete_job_templates(job_templates)
  end

  def check_retirement_potential
    return true unless retirement_potential?
    error_text = 'Destroy aborted.  Active Services require retirement resources associated with this instance.'
    errors[:base] << error_text
    throw :abort
  end

  def create_dialogs(config_info)
    [:provision, :retirement, :reconfigure].each_with_object({}) do |action, hash|
      info = config_info[action]
      next unless new_dialog_required?(info)
      hash[action] = {:dialog_id => create_new_dialog(info[:new_dialog_name], info[:extra_vars], info[:hosts]).id}
    end
  end

  def delete_job_templates(job_templates, action = nil)
    auth_user = User.current_userid || 'system'
    job_templates.each do |job_template|
      job_template.delete_in_provider_queue(auth_user)
      resource_actions.find_by(:action => action.capitalize).update_attributes(:configuration_template => nil) if action
    end
  end

  def new_dialog_required?(info)
    info && info.key?(:new_dialog_name) && !info.key?(:dialog_id)
  end

  def self.new_job_template_required?(info, action, service_template)
    return info && info.key?(:playbook_id) if service_template.nil?
    info && info.key?(:playbook_id) && service_template.job_template(action).nil?
  end
  private_class_method :new_job_template_required?

  def update_job_templates(name, description, config_info, auth_user)
    [:provision, :retirement, :reconfigure].each do |action|
      info = config_info[action]
      next unless info
      job_template = job_template(action)
      next unless job_template
      if info.key?(:playbook_id)
        _tower, params = self.class.send(:build_parameter_list, self.class.send(:build_name, name, action), description, info)
        job_template.update_in_provider_queue(params)
      else
        delete_job_templates([job_template], action)
      end
    end
  end

  def validate_update_config_info(options)
    opts = super
    self.class.send(:validate_config_info, opts)
  end

  # override
  def update_service_resources(_config_info, _auth_user = nil)
    # do nothing since no service resources for this template
  end

  # override
  def update_from_options(params)
    options[:config_info] = Hash[params[:config_info].collect { |k, v| [k, v.except(:configuration_template)] }]
    update_attributes!(params.except(:config_info))
  end
end
