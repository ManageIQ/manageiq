module Metric::CiMixin::StateFinders
  def vim_performance_state_for_ts(ts)
    return nil unless self.respond_to?(:vim_performance_states)

    @states_by_ts ||= {}
    state = @states_by_ts[ts]
    if state.nil?
      # TODO: vim_performance_states.loaded? works only when doing resource.vim_performance_states.all, not when loading
      # a subset based on available timestamps
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
        state = @states_by_ts[Metric::Helper.nearest_hourly_timestamp(Time.now.utc)]
        state ||= vim_performance_states.find_by(:timestamp => ts)
      end
      state ||= perf_capture_state
      @states_by_ts[state.timestamp.utc.iso8601] = state
    end

    state
  end

  def preload_vim_performance_state_for_ts_iso8601(conditions = {})
    @states_by_ts = vim_performance_states.where(conditions).index_by { |x| x.timestamp.utc.iso8601 }
  end

  # Use VimPerformanceState to populate the scopes with the values from a particular point in time
  # using @last_vps_ts to ensure we don't load at one time and then use at another
  def vim_performance_state_association(ts, assoc)
    if assoc.to_s == "miq_regions"
      return respond_to?(:miq_regions) ? miq_regions : MiqRegion.none
    end

    # this is a virtual reflection, just return the value
    if !self.class.reflect_on_association(assoc)
      return vim_performance_state_for_ts(ts).public_send(assoc)
    end

    if !defined?(@last_vps_ts) || @last_vps_ts != ts
      @last_vps_ts = ts
      # we are using a different timestamp
      # clear out relevant associations
      (VimPerformanceState::ASSOCIATIONS & self.class.reflections.keys.map(&:to_sym)).each do |vps_assoc|
        association(vps_assoc).reset
      end
    end

    if !association(assoc.to_sym).loaded?
      MiqPreloader.preload_from_array(self, assoc, vim_performance_state_for_ts(ts).public_send(assoc))
    end
    public_send(assoc)
  end
end
