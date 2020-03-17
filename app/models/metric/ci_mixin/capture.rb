module Metric::CiMixin::Capture
  def perf_capture_object(targets = nil)
    if self.kind_of?(ExtManagementSystem)
      self.class::MetricsCapture.new(targets, ext_management_system)
    else
      self.class.parent::MetricsCapture.new(targets || self, ext_management_system)
    end
  end

  delegate :perf_collect_metrics, :to => :perf_capture_object

  def perf_capture_realtime(*args)
    perf_capture('realtime', *args)
  end

  def perf_capture_hourly(*args)
    perf_capture('hourly', *args)
  end

  def perf_capture_historical(*args)
    perf_capture('historical', *args)
  end

  def perf_capture(interval_name, start_time = nil, end_time = nil)
    unless Metric::Capture::VALID_CAPTURE_INTERVALS.include?(interval_name)
      raise ArgumentError, _("invalid interval_name '%{name}'") % {:name => interval_name}
    end
    raise ArgumentError, _("end_time cannot be specified if start_time is nil") if start_time.nil? && !end_time.nil?

    # if target (== self) is archived, skip it
    if respond_to?(:ems_id) && ems_id.nil?
      _log.warn("C&U collection's target is archived (no EMS associated), skipping. Target: #{log_target}")
      return
    end

    start_time, end_time = fix_capture_start_end_time(interval_name, start_time, end_time)
    start_range, end_range, counters_data = just_perf_capture(interval_name, start_time, end_time)

    perf_process(interval_name, start_range, end_range, counters_data) if start_range
  end

  def fix_capture_start_end_time(interval_name, start_time, end_time)
    start_time = start_time.utc unless start_time.nil?
    end_time = end_time.utc unless end_time.nil?

    # Determine the start_time for capturing if not provided
    if interval_name == 'historical'
      start_time ||= Metric::Capture.historical_start_time
    elsif interval_name == "hourly"
      start_time ||= last_perf_capture_on || 4.hours.ago.utc
    else # interval_name == realtime
      start_time ||= [last_perf_capture_on, 4.hours.ago.utc.beginning_of_day].compact.max
    end
    [start_time, end_time]
  end

  # Determine the expected start time, so we can detect gaps or missing data
  # @param interval_name [String]
  # @param start_time [Date] start date passed to pref_capture
  # @return [String, nil] Expected start date for the gap.
  #     nil if none
  def calculate_gap(interval_name, start_time)
    expected_start_range = start_time
    # If we've changed power state within the last hour, the returned data
    #   may not include all the data we'd expect
    return if try(:state_changed_on) && state_changed_on > 1.hour.ago

    unless expected_start_range.nil?
      # Shift the expected time for first item, since you may not get back an
      #   item for the first timestamp.
      case interval_name
      when 'realtime' then expected_start_range += (1.minute / Metric::Capture::REALTIME_METRICS_PER_MINUTE)
      when 'hourly'   then expected_start_range += 1.hour
      end
      expected_start_range.iso8601
    end
  end

  def just_perf_capture(interval_name, start_time = nil, end_time = nil)
    log_header = "[#{interval_name}]"
    log_time = ''
    log_time << ", start_time: [#{start_time}]" unless start_time.nil?
    log_time << ", end_time: [#{end_time}]" unless end_time.nil?

    _log.info("#{log_header} Capture for #{log_target}#{log_time}...")

    start_range = end_range = counters = counter_values = counters_data = nil
    _, t = Benchmark.realtime_block(:total_time) do
      Benchmark.realtime_block(:capture_state) { perf_capture_state }

      interval_name_for_capture = interval_name == 'historical' ? 'hourly' : interval_name
      counters_by_mor, counter_values_by_mor_and_ts = perf_collect_metrics(interval_name_for_capture, start_time, end_time)

      counters       = counters_by_mor[ems_ref] || {}
      counter_values = counter_values_by_mor_and_ts[ems_ref] || {}

      ts = counter_values.keys.sort
      start_range = ts.first
      end_range   = ts.last
    end

    _log.info("#{log_header} Capture for #{log_target}#{log_time}...Complete - Timings: #{t.inspect}")

    if start_range.nil?
      _log.info("#{log_header} Skipping processing for #{log_target}#{log_time} as no metrics were captured.")
      # Set the last capture on to end_time to prevent forever queueing up the same collection range
      update(:last_perf_capture_on => end_time || Time.now.utc) if interval_name == 'realtime'
    else
      expected_start_range = calculate_gap(interval_name, start_time)
      if expected_start_range && start_range > expected_start_range
        _log.warn("#{log_header} For #{log_target}#{log_time}, expected to get data as of [#{expected_start_range}], but got data as of [#{start_range}].")

        # Raise ems_performance_gap_detected alert event to enable notification.
        MiqEvent.raise_evm_alert_event_queue(ext_management_system, "ems_performance_gap_detected",
                                             :resource_class       => self.class.name,
                                             :resource_id          => id,
                                             :expected_start_range => expected_start_range,
                                             :start_range          => start_range
                                            )
      end

      # Convert to format allowing to send multiple resources at once
      counters_data = {
        [self.class.base_class.name, self.id] => {
          :counters       => counters,
          :counter_values => counter_values
        }
      }
    end

    [start_range, end_range, counters_data]
  end

  def perf_capture_callback(task_ids, _status, _message, _result)
    tasks = MiqTask.where(:id => task_ids)
    tasks.each do |t|
      t.lock do |task|
        tkey = "#{self.class.name}:#{id}"
        task.context_data[:complete] << tkey
        task.pct_complete = (task.context_data[:complete].length.to_f / task.context_data[:targets].length.to_f) * 100

        if (task.context_data[:targets] - task.context_data[:complete]).empty?
          # Task is done, call the rollup on the parent
          task.state, task.status, task.message = [MiqTask::STATE_FINISHED, MiqTask::STATUS_OK, "Performance collection complete, #{task.context_data[:complete].length} out of #{task.context_data[:targets].length} collections completed"]

          # Splitting e.g. "ManageIQ::Providers::Openstack::InfraManager::Cluster:8" to class and id
          pclass, _, pid = task.context_data[:parent].rpartition(":")
          parent = pclass.constantize.find(pid)
          msg = "Queueing [#{task.context_data[:interval]}] rollup to #{parent.class.name} id: [#{parent.id}] for time range: [#{task.context_data[:start]} - #{task.context_data[:end]}]"
          _log.info("#{msg}...")
          parent.perf_rollup_range_queue(task.context_data[:start], task.context_data[:end], task.context_data[:interval])
          _log.info("#{msg}...Complete")
        else
          task.state, task.status, task.message = [MiqTask::STATE_ACTIVE, MiqTask::STATUS_OK, task.message = "Performance collection active, #{task.context_data[:complete].length} out of #{task.context_data[:targets].length} collections completed"]
        end
        _log.info("Updating task id: [#{task.id}] #{task.message}")
        task.save!
      end
    end
  end

  def perf_capture_state
    VimPerformanceState.capture(self)
  end

  def perf_capture_realtime_now
    # For UI to enable refresh of realtime charts on demand
    _log.info("Realtime capture requested for #{log_target}")

    perf_capture_object.perf_capture_realtime_queue
  end
end
