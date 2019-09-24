class ServiceTemplateTransformationPlan < ServiceTemplate
  include_concern 'ValidateConfigInfo'
  virtual_has_one :transformation_mapping

  supports :order do
    unmigrated_vms = vm_resources.reject { |res| res.resource.is_tagged_with?('transformation_status/migrated', :ns => '/managed') }
    unsupported_reason_add(:order, 'All VMs of the migration plan have already been successfully migrated') if unmigrated_vms.blank?
  end
  alias orderable?     supports_order?
  alias validate_order supports_order?

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

  def transformation_mapping_resource
    service_resources.where(:resource_type => 'TransformationMapping')
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

  def update_catalog_item(options, _auth_user = nil)
    raise _("Editing a plan in progress is prohibited") if %w(active pending).include?(miq_requests.sort_by(&:created_on).last.try(:request_state))

    if miq_requests.any? || options[:config_info].nil?
      update(:name => options[:name], :description => options[:description])
      return reload
    end

    added_vms_enhanced_config_info = validate_config_info(options)

    transaction do
      vm_resources.destroy_all
      reload
      update_from_options(options)
      transformation_mapping_resource.update(:resource_id => added_vms_enhanced_config_info[:transformation_mapping][:id])
      added_vms_enhanced_config_info[:vms].each { |vm_hash| add_resource(vm_hash[:vm], :status => ServiceResource::STATUS_QUEUED, :options => vm_hash[:options]) }
      save!
    end
    reload
  end

  private

  def enforce_single_service_parent(_resource)
  end
end
