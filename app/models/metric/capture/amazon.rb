module Metric::Capture::Amazon
  INTERVALS = [5.minutes, 1.minute]

  COUNTER_INFO = [
    {
      :amazon_counters       => ["CPUUtilization"],
      :calculation           => lambda { |stat, _| stat },
      :vim_style_counter_key => "cpu_usage_rate_average"
    },

    {
      :amazon_counters       => ["DiskReadBytes", "DiskWriteBytes"],
      :calculation           => lambda { |*stats, interval| stats.compact.sum / 1024.0 / interval },
      :vim_style_counter_key => "disk_usage_rate_average"
    },

    {
      :amazon_counters       => ["NetworkIn", "NetworkOut"],
      :calculation           => lambda { |*stats, interval| stats.compact.sum / 1024.0 / interval },
      :vim_style_counter_key => "net_usage_rate_average"
    },
  ]

  COUNTER_NAMES = COUNTER_INFO.collect { |i| i[:amazon_counters] }.flatten.uniq

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

    "disk_usage_rate_average" => {
      :counter_key           => "disk_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 2,
      :rollup                => "average",
      :unit_key              => "kilobytespersecond",
      :capture_interval_name => "realtime"
    },

    "net_usage_rate_average" => {
      :counter_key           => "net_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 2,
      :rollup                => "average",
      :unit_key              => "kilobytespersecond",
      :capture_interval_name => "realtime"
    }
  }
end
