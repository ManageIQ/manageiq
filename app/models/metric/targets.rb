module Metric::Targets
  cache_with_timeout(:perf_capture_always, 1.minute) do
    MiqRegion.my_region.perf_capture_always
  end

  def self.perf_capture_always=(options)
    perf_capture_always_clear_cache
    MiqRegion.my_region.perf_capture_always = options
  end

  def self.targets_archived_from
    archived_for_setting = Settings.performance.targets.archived_for
    archived_for_setting.to_i_with_method.seconds.ago.utc
  end
end
