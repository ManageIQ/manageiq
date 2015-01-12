module Metric::CiMixin::Rollup
  def perf_rollup_to_parent(interval_name, start_time, end_time = nil)
    parents = case interval_name
    when 'realtime'             then [self.perf_rollup_parent(interval_name), interval_name, self, 'hourly']
    when 'hourly', 'historical' then [self.perf_rollup_parent('hourly'),      interval_name, self, 'daily']
    when 'daily'                then []
    else raise ArgumentError, "invalid interval name #{interval_name}"
    end

    parents.each_slice(2) do |parent, new_interval|
      next if parent.nil?

      case new_interval
      when 'hourly', 'historical' then
        times = Metric::Helper.hours_from_range(start_time, end_time)

        log_header = "MIQ(#{self.class.name}.perf_rollup_to_parent) Queueing [#{new_interval}] rollup to #{parent.class.name} id: [#{parent.id}] for times: #{times.inspect}"
        $log.info "#{log_header}..."
        times.each { |t| parent.perf_rollup_queue(t, new_interval) }
        $log.info "#{log_header}...Complete"
      when 'daily' then
        times_by_tp = Metric::Helper.days_from_range_by_time_profile(start_time, end_time)
        times_by_tp.each do |tp, times|
          log_header = "MIQ(#{self.class.name}.perf_rollup_to_parent) Queueing [#{new_interval}] rollup to #{parent.class.name} id: [#{parent.id}] in time profile: [#{tp.description}] for times: #{times.inspect}"
          $log.info "#{log_header}..."
          times.each { |t| parent.perf_rollup_queue(t, new_interval, tp) }
          $log.info "#{log_header}...Complete"
        end
      end
    end
  end

  def perf_rollup_parent(interval_name=nil)
    raise NotImplementedError, "perf_rollup_parent must be overridden in the mixed-in class"
  end

  def perf_rollup_queue(time, interval_name, time_profile = nil)
    raise ArgumentError, "time_profile must be passed if interval name is 'daily'" if interval_name == 'daily' && time_profile.nil?
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
      :instance_id => self.id,
      :method_name => 'perf_rollup',
      :args        => args,
      :msg_timeout => Metric::Rollup::TIMEOUT_PROCESS,
      :zone        => self.my_zone,
      :role        => 'ems_metrics_processor',
      :queue_name  => 'ems_metrics_processor',
      :deliver_on  => deliver_on,
      :priority    => Metric::Capture.const_get("#{interval_name.upcase}_PRIORITY")
    ) do |msg|
      $log.debug "MIQ(#{self.class.name}.perf_rollup_queue) Skipping queueing [#{interval_name}] rollup of #{self.class.name} name: [#{self.name}], id: [#{self.id}] for time: [#{time}], since it is already queued" unless msg.nil?
    end
  end

  def perf_rollup(time, interval_name, time_profile = nil)
    raise ArgumentError, "time_profile must be passed if interval name is 'daily'" if interval_name == 'daily' && time_profile.nil?
    time_profile_id = TimeProfile.extract_ids(time_profile)
    klass, meth = Metric::Helper.class_and_association_for_interval_name(interval_name)

    log_header = "MIQ(#{self.class.name}.perf_rollup) [#{interval_name}] Rollup for #{self.class.name} name: [#{self.name}], id: [#{self.id}] for time: [#{time}]"
    $log.info("#{log_header}...")

    dummy, t = Benchmark.realtime_block(:total_time) do
      new_perf = {
        :timestamp => time,
        :capture_interval_name => (interval_name == 'historical' ? 'hourly' : interval_name)
      }
      new_perf[:time_profile_id] = time_profile_id unless time_profile_id.nil?

      perf = nil
      Benchmark.realtime_block(:db_find_prev_perf) do
        perf = self.send(meth).where(new_perf).first
        perf ||= self.send(meth).build(:resource_name => self.name)
      end

      Benchmark.realtime_block(:rollup_perfs) do
        new_perf = Metric::Rollup.send("rollup_#{interval_name}", self, time, interval_name, time_profile, new_perf, perf.attributes)
      end

      Benchmark.realtime_block(:db_update_perf) { perf.update_attributes(new_perf) }
      Benchmark.realtime_block(:process_perfs_tag) { VimPerformanceTagValue.build_from_performance_record(perf) }

      Benchmark.realtime_block(:process_bottleneck) { BottleneckEvent.generate_future_events(self) } if interval_name == 'hourly'

      self.perf_rollup_to_parent(interval_name, time)
    end

    $log.info("#{log_header}...Complete - Timings: #{t.inspect}")
  end

  def perf_rollup_range(start_time, end_time, interval_name, time_profile = nil)
    times = case interval_name
    when 'realtime'
      Metric::Helper.realtime_timestamps_from_range(start_time, end_time)
    when 'hourly'
      Metric::Helper.hours_from_range(start_time, end_time)
    when 'daily'
      raise ArgumentError, "time_profile must be passed if interval name is 'daily'" if time_profile.nil?
      time_profile = TimeProfile.extract_objects(time_profile)
      return if time_profile.nil? || !time_profile.rollup_daily_metrics
      Metric::Helper.days_from_range(start_time, end_time, time_profile.tz_or_default)
    end

    times.reverse.each { |t| self.perf_rollup(t, interval_name, time_profile) }

    # Raise <class>_perf_complete alert event if realtime so alerts can be evaluated.
    MiqEvent.raise_evm_alert_event_queue(self, MiqEvent.event_name_for_target(self, "perf_complete")) if interval_name == "realtime"
  end

  def perf_rollup_range_queue(start_time, end_time, interval_name, time_profile_id = nil, priority = MiqQueue::NORMAL_PRIORITY)
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :method_name => "perf_rollup_range",
      :instance_id => self.id,
      :zone        => self.my_zone,
      :role        => 'ems_metrics_processor',
      :queue_name  => 'ems_metrics_processor',
      :priority    => priority,
      :args        => [start_time, end_time, interval_name, time_profile_id]
    )
  end
end
