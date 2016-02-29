class ManageIQ::Providers::Openstack::NetworkManager::MetricsCapture < ManageIQ::Providers::Openstack::BaseMetricsCapture
  NETWORK_METERS = [].freeze

  # The list of meters that provide "cumulative" meters instead of "gauge"
  # meters from openstack.  The values from these meters will have to be
  # diffed against the previous value in order to grab a discrete value.
  DIFF_METERS    = NETWORK_METERS
  def self.diff_meter?(meters)
    meters = [meters] unless meters.kind_of? Array
    meters.all? { |m| DIFF_METERS.include? m }
  end

  COUNTER_INFO = [].freeze

  COUNTER_NAMES = COUNTER_INFO.collect { |i| i[:openstack_counters] }.flatten.uniq

  VIM_STYLE_COUNTERS = {}.freeze

  def perf_capture_data(start_time, end_time)
    resource_filter = {"field" => "resource_id", "value" => target.ems_ref}
    metadata_filter = {"field" => "metadata.instance_id", "value" => target.ems_ref}

    perf_capture_data_openstack_base(self.class, start_time, end_time, resource_filter,
                                     metadata_filter)
  end
end
