class ManageIQ::Providers::Openstack::InfraManager::MetricsCapture < ManageIQ::Providers::Openstack::BaseMetricsCapture
  def perf_capture_data(start_time, end_time)
    # Metadata filter covers all resources, resource filter can be nil
    resource_filter = nil
    metadata_filter = target.ems_ref_obj ? {"field" => "metadata.resource_id", "value" => target.ems_ref_obj} : nil

    perf_capture_data_openstack_base(ManageIQ::Providers::Openstack::InfraManager::MetricsCalculations, start_time, end_time, resource_filter,
                                     metadata_filter)
  end
end
