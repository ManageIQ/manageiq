class ServiceTemplateTransformationPlan < ServiceTemplate
  def request_class
    ServiceTemplateTransformationPlanRequest
  end

  def request_type
    "transformation_plan"
  end

  default_value_for :internal, true

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

  validates :name, :presence => true, :uniqueness => {:scope => [:tenant_id]}

  # create ServiceTemplate and supporting ServiceResources and ResourceActions
  # options
  #   :name
  #   :description
  #   :config_info
  #     :transformation_mapping_id
  #     :pre_service_id
  #     :post_service_id
  #     :actions => [
  #        {:vm_id => "1", :pre_service => true, :post_service => false},
  #        {:vm_id => "2", :pre_service => true, :post_service => true},
  #     ]
  #
  def self.create_catalog_item(options, _auth_user = nil)
    enhanced_config_info = validate_config_info(options)
    default_options =  {
      :display      => false,
      :prov_type    => 'transformation_plan'
    }

    transaction do
      create_from_options(options.merge(default_options)).tap do |service_template|
        service_template.add_resource(enhanced_config_info[:transformation_mapping])
        enhanced_config_info[:vms].each { |vm_hash| service_template.add_resource(vm_hash[:vm], :status => ServiceResource::STATUS_QUEUED, :options => vm_hash[:options]) }
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

    pre_service_id  = config_info[:pre_service].try(:id) || config_info[:pre_service_id]
    post_service_id = config_info[:post_service].try(:id) || config_info[:post_service_id]

    vms = []
    if config_info[:actions]
      vm_objects = VmOrTemplate.where(:id => config_info[:actions].collect { |vm_hash| vm_hash[:vm_id] }.compact).index_by(&:id).stringify_keys
      config_info[:actions].each do |vm_hash|
        vm_obj = vm_objects[vm_hash[:vm_id]] || vm_hash[:vm]
        next if vm_obj.nil?

        vm_options = {}
        vm_options[:pre_ansible_playbook_service_template_id] = pre_service_id if vm_hash[:pre_service]
        vm_options[:post_ansible_playbook_service_template_id] = post_service_id if vm_hash[:post_service]
        vms << {:vm => vm_obj, :options => vm_options}
      end
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
