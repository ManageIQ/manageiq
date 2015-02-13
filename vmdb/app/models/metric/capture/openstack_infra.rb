module Metric::Capture::OpenstackInfra
  CPU_METERS     = %w(hardware.system_stats.cpu.util)
  MEMORY_METERS  = %w(hardware.memory.used
                      hardware.memory.total)
  SWAP_METERS    = %w(hardware.memory.swap.avail
                      hardware.memory.swap.total)
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

  # TODO(lsmola) until we have hardware.memory.util in Ceilometer, we have to compute it, but this computation
  # should be done rather on the Ceilometer side
  def self.memory_util_calculation(stats, _)
    stats['hardware.memory.total'] > 0 ? 100.0 / stats['hardware.memory.total'] * stats['hardware.memory.used'] : 0
  end

  def self.memory_swapped_calculation(stats, _)
    total = stats['hardware.memory.swap.total']
    avail = stats['hardware.memory.swap.avail']
    # compute used swap from total and available, and convert it to megabytes from bytes
    total > 0 && total > avail ? (total - avail) / (1024.0 * 1024.0) : 0
  end

  def self.counter_sum_per_second_calculation(stats, intervals)
    total = 0.0
    stats.keys.each do |c|
      total += (intervals[c] > 0) ? stats[c] / intervals[c].to_f : 0
    end
    total
  end

  COUNTER_INFO   = [
    {
      :openstack_counters    => CPU_METERS,
      :calculation           => lambda { |stat, _| stat },
      :vim_style_counter_key => "cpu_usage_rate_average"
    },
    {
      :openstack_counters    => MEMORY_METERS,
      :calculation           => Metric::Capture::OpenstackInfra.method(:memory_util_calculation).to_proc,
      :vim_style_counter_key => "mem_usage_absolute_average"
    },
    {
      :openstack_counters    => SWAP_METERS,
      :calculation           => Metric::Capture::OpenstackInfra.method(:memory_swapped_calculation).to_proc,
      :vim_style_counter_key => "mem_swapped_absolute_average"
    },
    {
      :openstack_counters    => DISK_METERS,
      :calculation           => Metric::Capture::OpenstackInfra.method(:counter_sum_per_second_calculation).to_proc,
      :vim_style_counter_key => "disk_usage_rate_average"
    },
    {
      :openstack_counters    => NETWORK_METERS,
      :calculation           => Metric::Capture::OpenstackInfra.method(:counter_sum_per_second_calculation).to_proc,
      :vim_style_counter_key => "net_usage_rate_average"
    },
  ]

  COUNTER_NAMES = COUNTER_INFO.collect { |i| i[:openstack_counters] }.flatten.uniq

  VIM_STYLE_COUNTERS = {
    "cpu_usage_rate_average" => {
      :counter_key           => "cpu_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 1,
      :rollup                => "average",
      :unit_key              => "percent",
      :capture_interval_name => "realtime"
    },
    "mem_usage_absolute_average" => {
      :counter_key           => "mem_usage_absolute_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 1,
      :rollup                => "average",
      :unit_key              => "percent",
      :capture_interval_name => "realtime"
    },
    "mem_swapped_absolute_average" => {
      :counter_key           => "mem_swapped_absolute_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 1,
      :rollup                => "average",
      :unit_key              => "megabytes",
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
    "net_usage_rate_average" => {
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
