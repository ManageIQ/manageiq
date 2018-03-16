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
  alias orderable? validate_order

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
          elsif config_info[:vm_refs]
            validate_and_find_by_refs(mapping, config_info[:vm_refs])
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

  # refs_config is an array of hash
  # each hash can have keys: name(required), host, uid
  def self.validate_and_find_by_refs(_mapping, refs_array)
    refs_array.collect {|hash| vm_by_ref(hash) }
  end
  private_class_method :validate_and_find_by_refs

  def self.vm_by_ref(ref_hash)
    vm_name = ref_hash['name']

    conditions = {:name => vm_name}
    conditions[:uid_ems] = ref_hash['uid'] if ref_hash['uid'].present?
    vms = Vm.where(conditions)
    vms = vms.select { |vm| vm.host.name == ref_hash['host']} if ref_hash['host'].present?

    raise _("VM(#{vm_name} does not exist in inventory)") if vms.empty?
    raise _("Multiple VMs with name(#{vm_name}) in inventory") if vms.size > 1
    vms.first
  end
  private_class_method :vm_by_ref
end
