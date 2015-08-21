class Metric::CiMixin::Capture::Openstack < Metric::CiMixin::Capture::OpenstackBase
  def perf_capture_data(start_time, end_time)
    resource_filter = {"field" => "resource_id", "value" => target.ems_ref}
    metadata_filter = {"field" => "metadata.instance_id", "value" => target.ems_ref}

    perf_capture_data_openstack_base(Metric::Capture::Openstack, start_time, end_time, resource_filter,
                                     metadata_filter)
  end
end
