class ManageIQ::Providers::Openstack::CloudManager::MetricsCapture < ManageIQ::Providers::Openstack::BaseMetricsCapture
  CPU_METERS     = ["cpu_util"]
  DISK_METERS    = ["disk.read.bytes", "disk.write.bytes"]
  NETWORK_METERS = ["network.incoming.bytes", "network.outgoing.bytes"]

  # The list of meters that provide "cumulative" meters instead of "gauge"
  # meters from openstack.  The values from these meters will have to be
  # diffed against the previous value in order to grab a discrete value.
  DIFF_METERS    = DISK_METERS + NETWORK_METERS
  def self.diff_meter?(meters)
    meters = [meters] unless meters.kind_of? Array
    meters.all? { |m| DIFF_METERS.include? m }
  end

  def self.counter_sum_per_second_calculation(stats, intervals)
    total = 0.0
    stats.keys.each do |c|
      total += (intervals[c] > 0) ? stats[c] / intervals[c].to_f : 0
    end
    total / 1024.0
  end

  COUNTER_INFO   = [
    {
      :openstack_counters    => CPU_METERS,
      :calculation           => ->(stat, _) { stat },
      :vim_style_counter_key => "cpu_usage_rate_average"
    },

    {
      :openstack_counters    => DISK_METERS,
      :calculation           => method(:counter_sum_per_second_calculation).to_proc,
      :vim_style_counter_key => "disk_usage_rate_average"
    },

    {
      :openstack_counters    => NETWORK_METERS,
      :calculation           => method(:counter_sum_per_second_calculation).to_proc,
      :vim_style_counter_key => "net_usage_rate_average"
    },
  ]

  COUNTER_NAMES = COUNTER_INFO.collect { |i| i[:openstack_counters] }.flatten.uniq

  VIM_STYLE_COUNTERS = {
    "cpu_usage_rate_average"  => {
      :counter_key           => "cpu_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 1,
      :rollup                => "average",
      :unit_key              => "percent",
      :capture_interval_name => "realtime"
    },

    "disk_usage_rate_average" => {
      :counter_key           => "disk_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 2,
      :rollup                => "average",
      :unit_key              => "kilobytespersecond",
      :capture_interval_name => "realtime"
    },

    "net_usage_rate_average"  => {
      :counter_key           => "net_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 2,
      :rollup                => "average",
      :unit_key              => "kilobytespersecond",
      :capture_interval_name => "realtime"
    }
  }

  def perf_capture_data(start_time, end_time)
    resource_filter = {"field" => "resource_id", "value" => target.ems_ref}
    metadata_filter = {"field" => "metadata.instance_id", "value" => target.ems_ref}

    perf_capture_data_openstack_base(self.class, start_time, end_time, resource_filter,
                                     metadata_filter)
  end
end
