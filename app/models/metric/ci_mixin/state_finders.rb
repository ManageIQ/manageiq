module Metric::CiMixin::StateFinders
  def vim_performance_state_for_ts(ts)
    return nil unless self.respond_to?(:vim_performance_states)

    @states_by_ts ||= {}
    state = @states_by_ts[ts]
    if state.nil?
      if vim_performance_states.loaded?
        # Look for requested time in cache
        t = ts.to_time(:utc)
        state = vim_performance_states.detect { |s| s.timestamp == t }
        if state.nil?
          # Look for state for current hour in cache if still nil because the
          #   capture will return a state for the current hour only.
          t = Metric::Helper.nearest_hourly_timestamp(Time.now.utc).to_time(:utc)
          state = vim_performance_states.detect { |s| s.timestamp == t }
        end
      else
        state = vim_performance_states.find_by_timestamp(ts)
      end
      state ||= perf_capture_state
      @states_by_ts[ts] = state
    end

    state
  end

  def preload_vim_performance_state_for_ts(conditions = {})
    @states_by_ts = vim_performance_states.where(conditions).index_by(&:timestamp)
  end

  def hosts_from_vim_performance_state_for_ts(ts)
    vim_performance_state_for_ts(ts).hosts
  end

  def vms_from_vim_performance_state_for_ts(ts)
    vim_performance_state_for_ts(ts).vms
  end

  def ext_management_systems_from_vim_performance_state_for_ts(ts)
    vim_performance_state_for_ts(ts).ext_management_systems
  end

  def ems_clusters_from_vim_performance_state_for_ts(ts)
    vim_performance_state_for_ts(ts).ems_clusters
  end

  def storages_from_vim_performance_state_for_ts(ts)
    vim_performance_state_for_ts(ts).storages
  end

  def miq_regions_from_vim_performance_state_for_ts(_ts)
    self.respond_to?(:miq_regions) ? miq_regions : []
  end
end
