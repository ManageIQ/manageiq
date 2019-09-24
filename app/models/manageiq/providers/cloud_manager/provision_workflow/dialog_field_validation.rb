# These methods are available for dialog field validation, do not erase.
module ManageIQ::Providers::CloudManager::ProvisionWorkflow::DialogFieldValidation
  def validate_cloud_subnet(field, values, dlg, fld, value)
    return nil unless value.blank?
    return nil if get_value(values[:cloud_network]).to_i.zero?
    return nil unless get_value(values[field]).blank?
    "#{required_description(dlg, fld)} is required"
  end
end
