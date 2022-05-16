# These methods are available for dialog field validation, do not erase.
module ManageIQ::Providers::CloudManager::ProvisionWorkflow::DialogFieldValidation
  def validate_cloud_subnet(field, values, dlg, fld, value)
    return nil if value.present?
    return nil if get_value(values[:placement_auto])
    return nil if get_value(values[field]).present?

    "#{required_description(dlg, fld)} is required"
  end

  def validate_cloud_network(field, values, dlg, fld, value)
    return nil if value.present?
    return nil if get_value(values[:placement_auto])
    return nil if get_value(values[field]).present?

    "#{required_description(dlg, fld)} is required"
  end
end
