class ServiceTemplateContainerTemplate < ServiceTemplateGeneric
  def self.default_provisioning_entry_point(_service_type)
    '/Service/Generic/StateMachines/GenericLifecycle/provision'
  end

  def self.default_retirement_entry_point
    nil
  end

  # create ServiceTemplate and supporting ServiceResources and ResourceActions
  # options
  #   :name
  #   :description
  #   :service_template_catalog_id
  #   :config_info
  #     :provision
  #       :dialog_id or :dialog
  #       :container_template_id or :container_template
  #
  def self.create_catalog_item(options, _auth_user = nil)
    options     = options.merge(:service_type => SERVICE_TYPE_ATOMIC, :prov_type => 'generic_container_template')
    config_info = validate_config_info(options[:config_info])
    enhanced_config = config_info.deep_merge(
      :provision => {
        :configuration_template => container_template_from_config_info(config_info)
      }
    )

    transaction do
      create_from_options(options).tap do |service_template|
        service_template.create_resource_actions(enhanced_config)
      end
    end
  end

  def self.validate_config_info(info)
    info[:provision][:fqname] ||= default_provisioning_entry_point(SERVICE_TYPE_ATOMIC) if info.key?(:provision)

    # TODO: Add more validation for required fields
    info
  end
  private_class_method :validate_config_info

  def self.container_template_from_config_info(info)
    template_id = info[:provision][:container_template_id]
    template_id ? ContainerTemplate.find(template_id) : info[:provision][:container_template]
  end
  private_class_method :container_template_from_config_info

  def container_template
    resource_actions.find_by(:action => "Provision").try(:configuration_template)
  end

  def container_manager
    container_template.try(:ext_management_system)
  end

  def update_catalog_item(options, _auth_user = nil)
    config_info = validate_update_config_info(options)
    config_info[:provision][:configuration_template] ||= container_template_from_config_info(config_info) if config_info.key?(:provision)

    options[:config_info] = config_info

    super
  end

  private

  def container_template_from_config_info(info)
    self.class.send(:container_template_from_config_info, info)
  end

  def validate_update_config_info(options)
    opts = super
    self.class.send(:validate_config_info, opts)
  end

  def update_service_resources(_config_info, _auth_user = nil)
    # do nothing since no service resources for this template
  end

  def update_from_options(params)
    options[:config_info] = Hash[params[:config_info].collect { |k, v| [k, v.except(:configuration_template)] }]
    update!(params.except(:config_info))
  end
end
