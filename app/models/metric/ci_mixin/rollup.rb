module Metric::CiMixin::Rollup
  def perf_rollup_to_parents(interval_name, start_time, end_time = nil)
    parent_rollups, next_rollup_interval = case interval_name
                                           when 'realtime'             then [perf_rollup_parents(interval_name), 'hourly']
                                           when 'hourly', 'historical' then [perf_rollup_parents('hourly'), 'daily']
                                           when 'daily'                then [nil, nil]
                                           else raise ArgumentError, _("invalid interval name %{name}") %
                                                                       {:name => interval_name}
                                           end

    parents = parent_rollups.to_a.compact.flat_map { |p| [p, interval_name] }
    parents += [self, next_rollup_interval] unless next_rollup_interval.nil?

    parents.each_slice(2) do |parent, new_interval|
      next if parent.nil?

      case new_interval
      when 'hourly', 'historical' then
        times = Metric::Helper.hours_from_range(start_time, end_time)

        log_header = "Queueing [#{new_interval}] rollup to #{parent.class.name} id: [#{parent.id}] for times: #{times.inspect}"
        _log.info("#{log_header}...")
        times.each { |t| parent.perf_rollup_queue(t, new_interval) }
        _log.info("#{log_header}...Complete")
      when 'daily' then
        times_by_tp = Metric::Helper.days_from_range_by_time_profile(start_time, end_time)
        times_by_tp.each do |tp, times|
          log_header = "Queueing [#{new_interval}] rollup to #{parent.class.name} id: [#{parent.id}] in time profile: [#{tp.description}] for times: #{times.inspect}"
          _log.info("#{log_header}...")
          times.each { |t| parent.perf_rollup_queue(t, new_interval, tp) }
          _log.info("#{log_header}...Complete")
        end
      end
    end
  end

  def perf_rollup_parents(_interval_name = nil)
    raise NotImplementedError, _("perf_rollup_parents must be overridden in the mixed-in class")
  end

  def perf_rollup_queue(time, interval_name, time_profile = nil)
    if interval_name == 'daily' && time_profile.nil?
      raise ArgumentError, _("time_profile must be passed if interval name is 'daily'")
    end
    time_profile = TimeProfile.extract_objects(time_profile)

    deliver_on = case interval_name
                 when 'realtime'             then nil
                 when 'hourly', 'historical' then Metric::Helper.next_hourly_timestamp(time)
                 when 'daily'                then Metric::Helper.next_daily_timestamp(time, time_profile.tz_or_default)
                 end

    args = [time, interval_name]
    args << time_profile.id if interval_name == 'daily'

    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'perf_rollup',
      :args        => args,
      :msg_timeout => Metric::Rollup::TIMEOUT_PROCESS,
      :zone        => my_zone,
      :role        => 'ems_metrics_processor',
      :queue_name  => 'ems_metrics_processor',
      :deliver_on  => deliver_on,
      :priority    => Metric::Capture.interval_priority(interval_name)
    ) do |msg|
      _log.debug("Skipping queueing [#{interval_name}] rollup of #{self.class.name} name: [#{name}], id: [#{id}] for time: [#{time}], since it is already queued") unless msg.nil?
    end
  end

  def perf_rollup(time, interval_name, time_profile = nil)
    if interval_name == 'daily' && time_profile.nil?
      raise ArgumentError, _("time_profile must be passed if interval name is 'daily'")
    end
    time_profile = TimeProfile.extract_objects(time_profile)
    _klass, meth = Metric::Helper.class_and_association_for_interval_name(interval_name)

    log_header = "[#{interval_name}] Rollup for #{self.class.name} name: [#{name}], id: [#{id}] for time: [#{time}]"
    _log.info("#{log_header}...")

    _dummy, t = Benchmark.realtime_block(:total_time) do
      new_perf = {
        :timestamp             => time,
        :capture_interval_name => (interval_name == 'historical' ? 'hourly' : interval_name)
      }
      new_perf[:time_profile_id] = time_profile.id if time_profile

      perf = nil
      Benchmark.realtime_block(:db_find_prev_perf) do
        perf = send(meth).find_by(new_perf)
        perf ||= send(meth).build(:resource_name => name)
      end

      Benchmark.realtime_block(:rollup_perfs) do
        new_perf = Metric::Rollup.send("rollup_#{interval_name}", self, time, interval_name, time_profile, new_perf, perf.attributes.symbolize_keys)
      end

      Benchmark.realtime_block(:db_update_perf) { perf.update(new_perf) }

      case interval_name
      when "hourly"
        Benchmark.realtime_block(:process_bottleneck) { BottleneckEvent.generate_future_events(self) }
      when "daily"
        Benchmark.realtime_block(:process_operating_ranges) { generate_vim_performance_operating_range(time_profile) }
      end

      perf_rollup_to_parents(interval_name, time)
    end

    _log.info("#{log_header}...Complete - Timings: #{t.inspect}")
  end

  def perf_rollup_range(start_time, end_time, interval_name, time_profile = nil)
    times = case interval_name
            when 'realtime'
              Metric::Helper.realtime_timestamps_from_range(start_time, end_time)
            when 'hourly'
              Metric::Helper.hours_from_range(start_time, end_time)
            when 'daily'
              raise ArgumentError, _("time_profile must be passed if interval name is 'daily'") if time_profile.nil?
              time_profile = TimeProfile.extract_objects(time_profile)
              return if time_profile.nil? || !time_profile.rollup_daily_metrics
              Metric::Helper.days_from_range(start_time, end_time, time_profile.tz_or_default)
            end

    times.reverse_each { |t| perf_rollup(t, interval_name, time_profile) }

    # Raise <class>_perf_complete alert event if realtime so alerts can be evaluated.
    MiqEvent.raise_evm_alert_event_queue(self, MiqEvent.event_name_for_target(self, "perf_complete")) if interval_name == "realtime"
  end

  def perf_rollup_range_queue(start_time, end_time, interval_name, time_profile_id = nil, priority = MiqQueue::NORMAL_PRIORITY)
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :method_name => "perf_rollup_range",
      :instance_id => id,
      :zone        => my_zone,
      :role        => 'ems_metrics_processor',
      :queue_name  => 'ems_metrics_processor',
      :priority    => priority,
      :args        => [start_time, end_time, interval_name, time_profile_id]
    )
  end
end
