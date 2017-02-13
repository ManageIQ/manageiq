class ServiceTemplateAnsiblePlaybook < ServiceTemplateGeneric
  def self.default_provisioning_entry_point(_service_type)
    '/Service/Generic/StateMachines/GenericLifecycle/provision'
  end

  def self.default_retirement_entry_point
    '/Service/Generic/StateMachines/GenericLifecycle/retire'
  end

  def job_template(service_action)
    item = resource_actions.detect { |ra| ra.action == service_action }
    item.configuration_template if item
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
    options      = options.merge(:service_type => 'atomic', :prov_type => 'generic_ansible_playbook')
    service_name = options[:name]
    description  = options[:description]
    config_info  = validate_config_info(options)

    transaction do
      create(options.except(:config_info)).tap do |service_template|
        [:provision, :retirement, :reconfigure].each do |action|
          prepare_job_template_and_dialog(action, service_name, description, options) if config_info.key?(action)
        end
        service_template.create_resource_actions(config_info)
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

  def self.create_job_template(name, description, info)
    playbook = ManageIQ::Providers::AnsibleTower::ConfigurationManager::Playbook.find(info[:playbook_id])
    # tower = playbook.manager

    # params = {
    #   :name         => name,
    #   :description  => description || '',
    #   :extra_vars   => info[:variables] || {},
    #   :inventory_id => playbook.inventory_root_group,
    # }
    # tower.class.create_in_provider(tower, params)
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
