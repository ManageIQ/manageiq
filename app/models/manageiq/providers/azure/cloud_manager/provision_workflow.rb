class ManageIQ::Providers::Azure::CloudManager::ProvisionWorkflow < ManageIQ::Providers::CloudManager::ProvisionWorkflow
  def allowed_instance_types(_options = {})
    source = load_ar_obj(get_source_vm)
    ems    = source.try(:ext_management_system)
    return {} if ems.nil?
    flavors = ems.flavors
    flavors.each_with_object({}) { |f, hash| hash[f.id] = display_name_for_name_description(f) }
  end

  def allowed_resource_groups(_options = {})
    source = load_ar_obj(get_source_vm)
    ems    = source.try(:ext_management_system)
    return {} if ems.nil?
    resource_groups = ems.resource_groups
    resource_groups.each_with_object({}) { |rg, hash| hash[rg.id] = rg.name }
  end

  def allowed_cloud_subnets(_options = {})
    src = resources_for_ui
    if (cn = CloudNetwork.find_by(:id => src[:cloud_network_id]))
      cn.cloud_subnets.each_with_object({}) do |cs, hash|
        hash[cs.id] = "#{cs.name} (#{cs.cidr})"
      end
    else
      {}
    end
  end

  def validate_cloud_subnet(field, values, dlg, fld, value)
    return nil unless value.blank?
    return nil if get_value(values[:cloud_network]).to_i.zero?
    return nil unless get_value(values[field]).blank?
    "#{required_description(dlg, fld)} is required"
  end

  private

  def dialog_name_from_automate(message = 'get_dialog_name')
    super(message, {'platform' => 'azure'})
  end

  def self.provider_model
    ManageIQ::Providers::Azure::CloudManager
  end
end
