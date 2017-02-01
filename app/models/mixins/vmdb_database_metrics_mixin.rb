module VmdbDatabaseMetricsMixin
  def has_perf_data?(interval_name = "hourly")
    @has_perf_data ||= {}
    return @has_perf_data[interval_name] if @has_perf_data.key?(interval_name)
    @has_perf_data[interval_name] = my_metrics.exists?(:capture_interval_name => interval_name)
  end

  def first_or_last_capture(interval_name, sort_order)
    my_metrics
      .where(:capture_interval_name => interval_name)
      .select(:timestamp)
      .order(sort_order == "DESC" ? "timestamp DESC" : "timestamp ASC")
      .first.try(:timestamp)
  end
  private :first_or_last_capture

  def last_capture(interval_name = "hourly")
    first_or_last_capture(interval_name, "DESC")
  end

  def first_capture(interval_name = "hourly")
    first_or_last_capture(interval_name, "ASC")
  end

  def first_and_last_capture(interval_name = "hourly")
    [first_capture(interval_name), last_capture(interval_name)].compact
  end
end
