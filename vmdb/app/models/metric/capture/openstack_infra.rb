module Metric::Capture::OpenstackInfra
  CPU_METERS     = %w(hardware.system_stats.cpu.util)
  DISK_METERS    = %w(hardware.system_stats.io.outgoing.blocks
                      hardware.system_stats.io.incoming.blocks)
  NETWORK_METERS = %w(hardware.network.ip.incoming.datagrams
                      hardware.network.ip.outgoing.datagrams)

  # The list of meters that provide "cumulative" meters instead of "gauge"
  # meters from openstack.  The values from these meters will have to be
  # diffed against the previous value in order to grab a discrete value.
  DIFF_METERS    = DISK_METERS + NETWORK_METERS
  def self.diff_meter?(meters)
    meters = [meters] unless meters.kind_of? Array
    meters.all? { |m| DIFF_METERS.include? m }
  end

  COUNTER_INFO   = [
    {
      :openstack_counters    => CPU_METERS,
      :calculation           => lambda { |stat, _| stat },
      :vim_style_counter_key => "cpu_usage_rate_average"
    },

    {
      :openstack_counters    => DISK_METERS,
      :calculation           => lambda { |*stats, interval| stats.compact.sum / interval },
      :vim_style_counter_key => "disk_usage_rate_average"
    },

    {
      :openstack_counters    => NETWORK_METERS,
      :calculation           => lambda { |*stats, interval| stats.compact.sum / interval },
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
      :unit_key              => "blockspersecond",
      :capture_interval_name => "realtime"
    },

    "net_usage_rate_average"  => {
      :counter_key           => "net_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 2,
      :rollup                => "average",
      :unit_key              => "datagramspersecond",
      :capture_interval_name => "realtime"
    }
  }
end
