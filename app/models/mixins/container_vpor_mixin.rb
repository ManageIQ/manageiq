module ContainerVporMixin
  LIVE_PERF_TAG = '/managed/live_reports/hawkular_datasource'.freeze

  def max_cpu_usage_rate_average_avg_over_time_period
    unless vpor_live?
      super
      return
    end
    results = ManageIQ::Providers::Kubernetes::ContainerManager::LongTermAverages.get_averages_over_time_period(self)
    results[:avg][:max_cpu_usage_rate_average]
  end

  def max_mem_usage_absolute_average_avg_over_time_period
    unless vpor_live?
      super
      return
    end
    results = ManageIQ::Providers::Kubernetes::ContainerManager::LongTermAverages.get_averages_over_time_period(self)
    results[:avg][:max_mem_usage_absolute_average]
  end

  def max_cpu_usage_rate_average_high_over_time_period
    unless vpor_live?
      super
      return
    end
    max_cpu_usage_rate_average_avg_over_time_period
  end

  def max_mem_usage_absolute_average_high_over_time_period
    unless vpor_live?
      super
      return
    end
    max_mem_usage_absolute_average_avg_over_time_period
  end

  def max_cpu_usage_rate_average_low_over_time_period
    unless vpor_live?
      super
      return
    end
    max_cpu_usage_rate_average_avg_over_time_period
  end

  def max_mem_usage_absolute_average_low_over_time_period
    unless vpor_live?
      super
      return
    end
    max_mem_usage_absolute_average_avg_over_time_period
  end

  def vpor_live?
    class_name = self.class.name.demodulize
    ems = if class_name == "ContainerManager"
            self
          elsif try(:ems_id)
            ExtManagementSystem.find(ems_id)
          end

    ems && ems.tags.exists?(:name => LIVE_PERF_TAG)
  end
end
