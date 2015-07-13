module VmOrTemplate::RightSizing
  extend ActiveSupport::Concern

  included do
    virtual_column :aggressive_recommended_vcpus,              :type => :integer,    :uses => [:hardware, :vim_performance_operating_ranges]
    virtual_column :aggressive_recommended_mem,                :type => :integer,    :uses => [:hardware, :vim_performance_operating_ranges]
    virtual_column :aggressive_vcpus_recommended_change_pct,   :type => :float,      :uses => [:hardware, :vim_performance_operating_ranges]
    virtual_column :aggressive_vcpus_recommended_change,       :type => :integer,    :uses => [:hardware, :vim_performance_operating_ranges]
    virtual_column :aggressive_mem_recommended_change_pct,     :type => :float,      :uses => [:hardware, :vim_performance_operating_ranges]
    virtual_column :aggressive_mem_recommended_change,         :type => :integer,    :uses => [:hardware, :vim_performance_operating_ranges]

    virtual_column :moderate_recommended_vcpus,                :type => :integer,    :uses => [:hardware, :vim_performance_operating_ranges]
    virtual_column :moderate_recommended_mem,                  :type => :integer,    :uses => [:hardware, :vim_performance_operating_ranges]
    virtual_column :moderate_vcpus_recommended_change_pct,     :type => :float,      :uses => [:hardware, :vim_performance_operating_ranges]
    virtual_column :moderate_vcpus_recommended_change,         :type => :integer,    :uses => [:hardware, :vim_performance_operating_ranges]
    virtual_column :moderate_mem_recommended_change_pct,       :type => :float,      :uses => [:hardware, :vim_performance_operating_ranges]
    virtual_column :moderate_mem_recommended_change,           :type => :integer,    :uses => [:hardware, :vim_performance_operating_ranges]

    virtual_column :conservative_recommended_vcpus,            :type => :integer,    :uses => [:hardware]
    virtual_column :conservative_recommended_mem,              :type => :integer,    :uses => [:hardware]
    virtual_column :conservative_vcpus_recommended_change_pct, :type => :float,      :uses => [:hardware]
    virtual_column :conservative_vcpus_recommended_change,     :type => :integer,    :uses => [:hardware]
    virtual_column :conservative_mem_recommended_change_pct,   :type => :float,      :uses => [:hardware]
    virtual_column :conservative_mem_recommended_change,       :type => :integer,    :uses => [:hardware]

    # TODO: For backward compatibility - remove once reports are converted not to use these
    virtual_column :recommended_vcpus,                    :type => :integer,    :uses => :aggressive_recommended_vcpus
    virtual_column :recommended_mem,                      :type => :integer,    :uses => :aggressive_recommended_mem
    virtual_column :overallocated_vcpus_pct,              :type => :float,      :uses => :aggressive_vcpus_recommended_change_pct
    virtual_column :overallocated_mem_pct,                :type => :float,      :uses => :aggressive_mem_recommended_change_pct

    virtual_column :max_cpu_usage_rate_average_max_over_time_period,     :type => :float
    virtual_column :max_mem_usage_absolute_average_max_over_time_period, :type => :float
    virtual_column :cpu_usagemhz_rate_average_max_over_time_period,      :type => :float
    virtual_column :derived_memory_used_max_over_time_period,            :type => :float
  end

  module ClassMethods
    DEFAULT_CPU_RECOMMENDATION_MINIMUM = 1
    def cpu_recommendation_minimum
      VMDB::Config.new("vmdb").config.fetch_path(:recommendations, :cpu_minimum) || DEFAULT_CPU_RECOMMENDATION_MINIMUM
    end

    DEFAULT_MEM_RECOMMENDATION_MINIMUM = 32.megabytes
    def mem_recommendation_minimum
      min = (VMDB::Config.new("vmdb").config.fetch_path(:recommendations, :mem_minimum) || DEFAULT_MEM_RECOMMENDATION_MINIMUM).to_i_with_method
      min / 1.megabyte
    end
  end

  RIGHT_SIZING_VCOLS = [
    :aggressive_recommended_vcpus,
    :aggressive_recommended_mem,
    :aggressive_vcpus_recommended_change_pct,
    :aggressive_vcpus_recommended_change,
    :aggressive_mem_recommended_change_pct,
    :aggressive_mem_recommended_change,

    :moderate_recommended_vcpus,
    :moderate_recommended_mem,
    :moderate_vcpus_recommended_change_pct,
    :moderate_vcpus_recommended_change,
    :moderate_mem_recommended_change_pct,
    :moderate_mem_recommended_change,

    :conservative_recommended_vcpus,
    :conservative_recommended_mem,
    :conservative_vcpus_recommended_change_pct,
    :conservative_vcpus_recommended_change,
    :conservative_mem_recommended_change_pct,
    :conservative_mem_recommended_change,

    :recommended_vcpus,
    :recommended_mem,
    :overallocated_vcpus_pct,
    :overallocated_mem_pct,

    :max_cpu_usage_rate_average_max_over_time_period,
    :max_mem_usage_absolute_average_max_over_time_period,
    :cpu_usagemhz_rate_average_max_over_time_period,
    :derived_memory_used_max_over_time_period
  ]

  RIGHT_SIZING_MODES = {
    :aggressive   => {:mem => :max_mem_usage_absolute_average_avg_over_time_period,  :cpu => :max_cpu_usage_rate_average_avg_over_time_period  },
    :moderate     => {:mem => :max_mem_usage_absolute_average_high_over_time_period, :cpu => :max_cpu_usage_rate_average_high_over_time_period },
    :conservative => {:mem => :max_mem_usage_absolute_average_max_over_time_period,  :cpu => :max_cpu_usage_rate_average_max_over_time_period  },
  }
  MEMORY_RECOMMENDATION_ROUND_TO_NEAREST = 4

  RIGHT_SIZING_MODES.each do |mode, meth|
    define_method("#{mode}_recommended_vcpus") do
      base_recommended(self.send(meth[:cpu]), num_cpu, self.class.cpu_recommendation_minimum)  unless num_cpu.nil?
    end

    define_method("#{mode}_recommended_mem") do
      base_recommended(self.send(meth[:mem]), ram_size, self.class.mem_recommendation_minimum, MEMORY_RECOMMENDATION_ROUND_TO_NEAREST) unless ram_size.nil?
    end

    define_method("#{mode}_vcpus_recommended_change_pct") do
      base_change_percentage(self.send("#{mode}_recommended_vcpus"), num_cpu) unless num_cpu.nil?
    end

    define_method("#{mode}_mem_recommended_change_pct") do
      base_change_percentage(self.send("#{mode}_recommended_mem"), ram_size) unless ram_size.nil?
    end

    define_method("#{mode}_vcpus_recommended_change") do
      base_change(self.send("#{mode}_recommended_vcpus"), num_cpu) unless num_cpu.nil?
    end

    define_method("#{mode}_mem_recommended_change") do
      base_change(self.send("#{mode}_recommended_mem"), ram_size) unless ram_size.nil?
    end
  end

  #####################################################
  # BACKWARD COMPATIBILITY for REPORTS THAT USE THESE
  #####################################################
  alias :recommended_vcpus       :aggressive_recommended_vcpus
  alias :recommended_mem         :aggressive_recommended_mem
  alias :overallocated_vcpus_pct :aggressive_vcpus_recommended_change_pct
  alias :overallocated_mem_pct   :aggressive_mem_recommended_change_pct

  def max_cpu_usage_rate_average_max_over_time_period
    perfs = VimPerformanceAnalysis.find_perf_for_time_period(self, "daily", :end_date => Time.now.utc, :days => Metric::LongTermAverages::AVG_DAYS)
    perfs.collect do |p|
      # Ignore any CPU bursts to 100% 15 minutes after VM booted
      next if (p.abs_max_cpu_usage_rate_average_value == 100.0) && self.boot_time && (p.abs_max_cpu_usage_rate_average_timestamp <= (self.boot_time + 15.minutes))
      p.abs_max_cpu_usage_rate_average_value
    end.compact.max
  end

  def max_mem_usage_absolute_average_max_over_time_period
    perfs = VimPerformanceAnalysis.find_perf_for_time_period(self, "daily", :end_date => Time.now.utc, :days => Metric::LongTermAverages::AVG_DAYS)
    perfs.collect(&:abs_max_mem_usage_absolute_average_value).compact.max
  end

  def cpu_usagemhz_rate_average_max_over_time_period
    perfs = VimPerformanceAnalysis.find_perf_for_time_period(self, "daily", :end_date => Time.now.utc, :days => Metric::LongTermAverages::AVG_DAYS)
    perfs.collect(&:cpu_usagemhz_rate_average).compact.max
  end

  def derived_memory_used_max_over_time_period
    perfs = VimPerformanceAnalysis.find_perf_for_time_period(self, "daily", :end_date => Time.now.utc, :days => Metric::LongTermAverages::AVG_DAYS)
    perfs.collect(&:derived_memory_used).compact.max
  end

  private

  def base_recommended(max, actual, min = nil, round_to_nearest = nil)
    return if actual.nil? || max.nil?

    recommendation = ((actual * max / 100.0) + 0.1).ceil
    recommendation = recommendation.round_up(round_to_nearest) if round_to_nearest.kind_of?(Numeric)
    recommendation = [recommendation, min].max if min.kind_of?(Numeric)
    recommendation
  end

  def base_change(recommended, actual)
    return if actual.nil? || recommended.nil?
    actual - recommended
  end

  def base_change_percentage(recommended, actual)
    return if actual.nil? || recommended.nil?
    return 0 if recommended == 0

    div = (actual.to_f / recommended.to_f)
    return 0 if div == 0

    result = ((1 - (1 / div)) * 1000).round  / 10.0
  end

end
