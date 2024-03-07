module Metric::CiMixin::StateFinders
  # load from cache or create a VimPerformanceState for a given timestamp
  #
  # for a cache:
  #   use preload to populate vim_performance_states associations
  #     this loads all records
  #     the cache is indexed by a Time object
  #     used by Metric.rollup / rollup_hourly
  #   preload_vim_performance_state_for_ts_iso8601 to populate @states_by_ts
  #       contains a subset, typically top of the hour and the timestamp of interest
  #       the cache is indexed by a String in iso8601 form
  #       used by: CiMixin::Processing#perf_process
  # @param ts [Time|String] beginning of hour timestamp (prefer Time)
  def vim_performance_state_for_ts(ts)
    ts = Time.parse(ts).utc if ts.kind_of?(String)
    ts_iso = ts.utc.iso8601
    return nil unless respond_to?(:vim_performance_states)

    @states_by_ts ||= {}
    state = @states_by_ts[ts_iso]
    if state.nil?
      # using preloaded vim_performance_states association
      if vim_performance_states.loaded?
        # Look for requested time in cache
        state = vim_performance_states.detect { |s| s.timestamp == ts }
        if state.nil?
          # Look for state for current hour in cache
          ts_iso_now = Metric::Helper.nearest_hourly_timestamp(Time.now.utc)
          t = ts_iso_now.to_time(:utc)
          state = vim_performance_states.detect { |s| s.timestamp == t }
        end
        # look for state from previous perf_capture_state call
        state ||= @states_by_ts[ts_iso_now]
      else
        ts_iso_now = Metric::Helper.nearest_hourly_timestamp(Time.now.utc)
        state = @states_by_ts[ts_iso_now]
        unless ts_iso_now == ts_iso
          state ||= vim_performance_states.find_by(:timestamp => ts)
        end
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
