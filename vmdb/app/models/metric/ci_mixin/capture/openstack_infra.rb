module Metric::CiMixin::Capture::OpenstackInfra
  def perf_capture_data_openstack_infra(start_time, end_time)
    # Metadata filter covers all resources, resource filter can be nil
    resource_filter = nil
    metadata_filter = ems_ref_obj ? {"field" => "metadata.resource_id", "value" => ems_ref_obj} : nil

    perf_capture_data_openstack_base(Metric::Capture::OpenstackInfra, start_time, end_time, resource_filter,
                                     metadata_filter)
  end
end
