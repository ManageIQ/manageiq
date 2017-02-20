module ContainerVporMixin
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
    true
  end
end
