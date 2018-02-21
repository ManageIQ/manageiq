class ServiceTemplateTransformationPlan < ServiceTemplate
  def request_class
    ServiceTemplateTransformationPlanRequest
  end

  def request_type
    "transformation_plan"
  end

  def transformation_mapping
    service_resources.find_by(:resource_type => 'TransformationMapping').resource
  end

  def vm_resources
    service_resources.where(:resource_type => 'VmOrTemplate')
  end

  def validate_order
    true
  end

  def self.default_provisioning_entry_point(_service_type)
    '/Transformation/StateMachines/VMTransformation/Transformation'
  end

  def self.default_retirement_entry_point
    nil
  end

  def self.default_reconfiguration_entry_point
    nil
  end

  # create ServiceTemplate and supporting ServiceResources and ResourceActions
  # options
  #   :name
  #   :description
  #   :config_info
  #     :transformation_mapping_id
  #     :vm_ids
  #
  def self.create_catalog_item(options, _auth_user = nil)
    enhanced_config_info = validate_config_info(options)
    default_options =  {
      :display      => false,
      :service_type => 'atomic',
      :prov_type    => 'transformation_plan'
    }

    transaction do
      create_from_options(options.merge(default_options)).tap do |service_template|
        service_template.add_resource(enhanced_config_info[:transformation_mapping])
        enhanced_config_info[:vms].each { |vm| service_template.add_resource(vm, :status => 'Queued') }
        service_template.create_resource_actions(enhanced_config_info)
      end
    end
  end

  private

  def enforce_single_service_parent(_resource)
  end

  def self.validate_config_info(options)
    config_info = options[:config_info]

    mapping = if config_info[:transformation_mapping_id]
                TransformationMapping.find(config_info[:transformation_mapping_id])
              else
                config_info[:transformation_mapping]
              end

    raise _('Must provide an existing transformation mapping') if mapping.blank?

    vms = if config_info[:vm_ids]
            VmOrTemplate.find(config_info[:vm_ids])
          else
            config_info[:vms]
          end

    raise _('Must select a list of valid vms') if vms.blank?

    {
      :transformation_mapping => mapping,
      :vms                    => vms,
      :provision              => config_info[:provision] || {}
    }
  end
  private_class_method :validate_config_info
end
