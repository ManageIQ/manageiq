module Metric::CiMixin::Capture
  include_concern 'Vim'
  include_concern 'Rhevm'
  include_concern 'Amazon'
  include_concern 'Openstack'

  def perf_collect_metrics(*args)
    case self
    when HostVmware, VmVmware; perf_collect_metrics_vim(*args)
    when HostRedhat, VmRedhat; perf_collect_metrics_rhevm(*args)
    when VmAmazon;             perf_collect_metrics_amazon(*args)
    when VmOpenstack;          perf_collect_metrics_openstack(*args)
    else raise "Unsupported type #{self.class.name} (id: #{self.id})"
    end
  end

  def queue_name_for_metrics_collection
    ems = if self.kind_of?(ExtManagementSystem)
      self
    elsif self.kind_of?(Storage)
      self.ext_management_systems.first
    elsif self.respond_to?(:ext_management_system)
      self.ext_management_system
    else
      raise "Unsupported type #{self.class.name} (id: #{self.id})"
    end

    ems.class.name[3..-1].underscore
  end

  def perf_capture_queue(interval_name, options = {})
    start_time = options[:start_time]
    end_time   = options[:end_time]
    force      = options[:force] # Force capture to run regardless of last capture time
    priority   = options[:priority] || Metric::Capture.const_get("#{interval_name.upcase}_PRIORITY")
    task_id    = options[:task_id]

    raise ArgumentError, "invalid interval_name '#{interval_name}'" unless Metric::Capture::VALID_CAPTURE_INTERVALS.include?(interval_name)
    raise ArgumentError, "end_time cannot be specified if start_time is nil" if start_time.nil? && !end_time.nil?

    start_time = start_time.utc unless start_time.nil?
    end_time = end_time.utc unless end_time.nil?

    log_header = "MIQ(#{self.class.name}.perf_capture_queue)"
    log_target = "#{self.class.name} name: [#{self.name}], id: [#{self.id}]"

    if interval_name != 'historical' && start_time.nil? && !force && !self.perf_capture_now?
      $log.debug "#{log_header} Skipping capture of #{log_target} - Performance last captured on [#{self.last_perf_capture_on}] is within threshold"
      return
    end

    # Determine what items we should be queuing up
    items = []
    cb = nil
    if interval_name == 'historical'
      start_time = Metric::Capture.historical_start_time if start_time.nil?
      end_time = Time.now.utc if end_time.nil?

      start_hour = start_time
      while start_hour != end_time
        end_hour = start_hour + 1.day
        end_hour = end_time if end_hour > end_time
        items.unshift([interval_name, start_hour, end_hour])
        start_hour = end_hour
      end
    else
      items << [interval_name]
      items[0] << start_time << end_time unless start_time.nil?

      cb = {:class_name => self.class.name, :instance_id => self.id, :method_name => :perf_capture_callback, :args => [[task_id]]} if task_id
    end

    # Queue up the actual items
    queue_item = {
      :class_name  => self.class.name,
      :instance_id => self.id,
      :method_name => 'perf_capture',
      :role        => 'ems_metrics_collector',
      :queue_name  => self.queue_name_for_metrics_collection,
      :zone        => self.my_zone,
      :state       => ['ready', 'dequeue'],
    }

    items.each do |item|
      MiqQueue.put_or_update(
        queue_item.merge(:args => item)
      ) do |msg, qi|
        if msg.nil?
          qi[:priority] = priority
          qi.delete(:state)
          qi[:miq_callback] = cb if cb
          qi
        elsif msg.state == "ready" && (task_id || MiqQueue.higher_priority?(priority, msg.priority))
          qi[:priority] = priority
          #rerun the job (either with new task or higher priority)
          qi.delete(:state)
          if task_id
            existing_tasks = (((msg.miq_callback || {})[:args] || []).first) || []
            qi[:miq_callback] = cb.merge(:args => [existing_tasks + [task_id]])
          end
          qi
        else
          $log.debug "#{log_header} Skipping capture of #{log_target} - Performance capture for interval #{qi[:args].inspect} is still running"
          #NOTE: do not update the message queue
          nil
        end
      end
    end
  end

  def perf_capture(interval_name, start_time = nil, end_time = nil)
    raise ArgumentError, "invalid interval_name '#{interval_name}'" unless Metric::Capture::VALID_CAPTURE_INTERVALS.include?(interval_name)
    raise ArgumentError, "end_time cannot be specified if start_time is nil" if start_time.nil? && !end_time.nil?

    start_time = start_time.utc unless start_time.nil?
    end_time = end_time.utc unless end_time.nil?

    log_header = "MIQ(#{self.class.name}.perf_capture) [#{interval_name}]"
    log_target = "#{self.class.name} name: [#{self.name}], id: [#{self.id}]"
    log_target << ", start_time: [#{start_time}]" unless start_time.nil?
    log_target << ", end_time: [#{end_time}]" unless end_time.nil?

    # Determine the start_time for capturing if not provided
    if interval_name == 'historical'
      start_time = Metric::Capture.historical_start_time if start_time.nil?

      interval_name_for_capture = 'hourly'
    else
      start_time = self.last_perf_capture_on if start_time.nil?
      if start_time.nil? && interval_name == 'hourly'
        # For hourly on the first capture, we don't want to get all of the
        #   historical data, so we shorten the query
        start_time = 4.hours.ago.utc
      end

      interval_name_for_capture = interval_name
    end

    # Determine the expected start time, so we can detect gaps or missing data
    expected_start_range = start_time
    # If we've changed power state within the last hour, the returned data
    #   may not include all the data we'd expect
    expected_start_range = nil if self.respond_to?(:state_changed_on) && self.state_changed_on && self.state_changed_on > Time.now.utc - 1.hour

    unless expected_start_range.nil?
      # Shift the expected time for first item, since you may not get back an
      #   item for the first timestamp.
      case interval_name
      when 'realtime' then expected_start_range = expected_start_range + (1.minute / Metric::Capture::Vim::REALTIME_METRICS_PER_MINUTE)
      when 'hourly'   then expected_start_range = expected_start_range + 1.hour
      end
      expected_start_range = expected_start_range.iso8601
    end

    $log.info "#{log_header} Capture for #{log_target}..."

    start_range = end_range = counters = counter_values = nil
    dummy, t = Benchmark.realtime_block(:total_time) do
      Benchmark.realtime_block(:capture_state) { self.perf_capture_state }

      counters_by_mor, counter_values_by_mor_and_ts = self.perf_collect_metrics(interval_name_for_capture, start_time, end_time)

      counters       = counters_by_mor[self.ems_ref] || {}
      counter_values = counter_values_by_mor_and_ts[self.ems_ref] || {}

      ts = counter_values.keys.sort
      start_range = ts.first
      end_range   = ts.last
    end

    $log.info "#{log_header} Capture for #{log_target}...Complete - Timings: #{t.inspect}"

    if start_range.nil?
      $log.info "#{log_header} Skipping processing for #{log_target} as no metrics were captured."
    else
      if expected_start_range && start_range > expected_start_range
        $log.warn "#{log_header} For #{log_target}, expected to get data as of [#{expected_start_range}], but got data as of [#{start_range}]."

        # Raise ems_performance_gap_detected alert event to enable notification.
        MiqEvent.raise_evm_alert_event_queue(self.ext_management_system, "ems_performance_gap_detected",
          {
            :resource_class       => self.class.name,
            :resource_id          => self.id,
            :expected_start_range => expected_start_range,
            :start_range          => start_range
          }
        )
      end
      self.perf_process(interval_name, start_range, end_range, counters, counter_values)
    end
  end

  def perf_capture_callback(task_ids, status, message, result)
    log_header = "MIQ(#{self.class.name}.perf_capture_callback)"
    tasks = MiqTask.find_all_by_id(task_ids)
    tasks.each do |t|
      t.lock do |task|
        tkey = "#{self.class.name}:#{self.id}"
        task.context_data[:complete] << tkey
        task.pct_complete = (task.context_data[:complete].length.to_f / task.context_data[:targets].length.to_f) * 100

        if (task.context_data[:targets] - task.context_data[:complete]).empty?
          # Task is done, call the rollup on the parent
          task.state, task.status, task.message = [MiqTask::STATE_FINISHED, MiqTask::STATUS_OK, "Performance collection complete, #{task.context_data[:complete].length} out of #{task.context_data[:targets].length} collections completed"]

          pclass, pid = task.context_data[:parent].split(":")
          parent = pclass.constantize.find(pid)
          msg = "#{log_header} Queueing [#{task.context_data[:interval]}] rollup to #{parent.class.name} id: [#{parent.id}] for time range: [#{task.context_data[:start]} - #{task.context_data[:end]}]"
          $log.info "#{msg}..."
          parent.perf_rollup_range_queue(task.context_data[:start], task.context_data[:end], task.context_data[:interval])
          $log.info "#{msg}...Complete"
        else
          task.state, task.status, task.message = [MiqTask::STATE_ACTIVE, MiqTask::STATUS_OK, task.message = "Performance collection active, #{task.context_data[:complete].length} out of #{task.context_data[:targets].length} collections completed"]
        end
        $log.info("#{log_header} Updating task id: [#{task.id}] #{task.message}")
        task.save!
      end
    end
  end

  def perf_capture_state
    VimPerformanceState.capture(self)
  end

  def perf_capture_realtime_now
    # For UI to enable refresh of realtime charts on demand
    log_header = "MIQ(#{self.class.name}.perf_capture_realtime_now)"
    log_target = "#{self.class.name} name: [#{self.name}], id: [#{self.id}]"

    $log.info "#{log_header} Realtime capture requested for #{log_target}"

    self.perf_capture_queue('realtime', :force => true, :priority => MiqQueue::HIGH_PRIORITY)
  end

  def perf_capture_now?
    self.last_perf_capture_on.nil? || (self.last_perf_capture_on < Metric::Capture.capture_threshold(self))
  end
end
