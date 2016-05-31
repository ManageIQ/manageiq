# These methods are available for dialog field validation, do not erase.
module ManageIQ::Providers::Openstack::CloudManager::ProvisionWorkflow::DialogFieldValidation
  def validate_cloud_network(field, values, dlg, fld, value)
    return nil if allowed_cloud_networks.length <= 1
    validate_placement(field, values, dlg, fld, value)
  end
end
