class ServiceTemplateAnsiblePlaybook < ServiceTemplateGeneric
  before_destroy :check_retirement_potential, :prepend => true

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
  def self.create_catalog_item(options, _auth_user)
    options      = options.merge(:service_type => SERVICE_TYPE_ATOMIC, :prov_type => 'generic_ansible_playbook')
    config_info  = validate_config_info(options[:config_info])

    transaction do
      create_from_options(options).tap do |service_template|
        dialog_ids = service_template.send(:create_dialogs, config_info)
        config_info.deep_merge!(dialog_ids)
        service_template.options[:config_info].deep_merge!(dialog_ids)
        service_template.create_resource_actions(config_info)
      end
    end
  end

  def create_new_dialog(dialog_name, extra_vars, hosts)
    Dialog::AnsiblePlaybookServiceDialog.create_dialog(dialog_name, extra_vars, hosts)
  end
  private :create_new_dialog

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

  def playbook(action)
    ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook.find(config_info[action.downcase.to_sym][:playbook_id])
  end

  def repository(action)
    GitRepository.find(config_info[action.downcase.to_sym][:repository_id])
  end

  def update_catalog_item(options, auth_user = nil)
    config_info = validate_update_config_info(options)
    unless config_info
      update!(options)
      return reload
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

  def new_dialog_required?(info)
    info && info.key?(:new_dialog_name) && !info.key?(:dialog_id)
  end

  def validate_update_config_info(options)
    opts = super
    return unless options.key?(:config_info)

    self.class.send(:validate_config_info, opts)
  end

  # override
  def update_service_resources(_config_info, _auth_user = nil)
    # do nothing since no service resources for this template
  end

  # override
  def update_from_options(params)
    options[:config_info] = Hash[params[:config_info].collect { |k, v| [k, v.except(:configuration_template)] }]
    update!(params.except(:config_info))
  end
end
