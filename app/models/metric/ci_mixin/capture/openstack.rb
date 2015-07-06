module Metric::CiMixin::Capture::Openstack
  def perf_capture_data_openstack(start_time, end_time)
    resource_filter = {"field" => "resource_id", "value" => ems_ref}
    metadata_filter = {"field" => "metadata.instance_id", "value" => ems_ref}

    perf_capture_data_openstack_base(Metric::Capture::Openstack, start_time, end_time, resource_filter,
                                     metadata_filter)
  end
end
