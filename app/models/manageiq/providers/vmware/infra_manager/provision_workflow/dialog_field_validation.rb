# These methods are available for dialog field validation, do not erase.
module ManageIQ::Providers::Vmware::InfraManager::ProvisionWorkflow::DialogFieldValidation
  def validate_placement_host_name(field, values, dlg, fld, value)
    result = validate_placement(field, values, dlg, fld, value)
    return result if result.nil?

    ems_cluster = EmsCluster.find_by(:id => get_value(values[:placement_cluster_name]))

    if ems_cluster.nil?
      _("Either Host Name or Cluster Name is required")
    elsif !ems_cluster.drs_enabled
      _("%{field_required} for Non-DRS enabled cluster") % {:field_required => result}
    end
  end
end
