module Metric::Capture
  VALID_CAPTURE_INTERVALS = ['realtime', 'hourly', 'historical'].freeze

  # This is nominally a VMware-specific value, but we currently expect
  # all providers to conform to it.
  REALTIME_METRICS_PER_MINUTE = 3

  REALTIME_PRIORITY = HOURLY_PRIORITY = DAILY_PRIORITY = MiqQueue::NORMAL_PRIORITY
  HISTORICAL_PRIORITY = MiqQueue::LOW_PRIORITY

  def self.capture_cols
    Metric.columns_hash.collect { |c, h| c.to_sym if h.type == :float && c[0, 7] != "derived" }.compact
  end

  def self.historical_days
    (VMDB::Config.new("vmdb").config.fetch_path(:performance, :history, :initial_capture_days) || 7).to_i
  end

  def self.historical_start_time
    historical_days.days.ago.utc.beginning_of_day
  end

  def self.concurrent_requests(interval_name)
    requests = VMDB::Config.new("vmdb").config.fetch_path(:performance, :concurrent_requests, interval_name.to_sym)
    requests ||= interval_name == 'realtime' ? 20 : 1
    requests = 20 if requests < 20 && interval_name == 'realtime'
    requests
  end

  def self.perf_capture_timer(zone = nil)
    _log.info "Queueing performance capture..."

    zone ||= MiqServer.my_server.zone(true)
    perf_capture_health_check(zone)
    targets = Metric::Targets.capture_targets(zone)

    targets_by_rollup_parent = calc_targets_by_rollup_parent(targets)
    tasks_by_rollup_parent   = calc_tasks_by_rollup_parent(targets_by_rollup_parent)
    queue_captures(targets, targets_by_rollup_parent, tasks_by_rollup_parent)

    # Purge tasks older than 4 hours
    MiqTask.delete_older(4.hours.ago.utc, "name LIKE 'Performance rollup for %'")

    _log.info "Queueing performance capture...Complete"
  end

  def self.perf_capture_gap(start_time, end_time, zone = nil)
    _log.info "Queueing performance capture for range: [#{start_time} - #{end_time}]..."

    targets = Metric::Targets.capture_targets(zone, :exclude_storages => true)
    targets.each { |target| target.perf_capture_queue('historical', :start_time => start_time, :end_time => end_time) }

    _log.info "Queueing performance capture for range: [#{start_time} - #{end_time}]...Complete"
  end

  def self.perf_capture_gap_queue(start_time, end_time, zone = nil)
    item = {
      :class_name  => name,
      :method_name => "perf_capture_gap",
      :role        => "ems_metrics_coordinator",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :args        => [start_time, end_time, zone]
    }

    zone = Zone.find(zone) if zone.kind_of?(Integer)
    item[:zone] = zone.name if zone.kind_of?(Zone)

    MiqQueue.put(item)
  end

  private

  def self.capture_threshold(target)
    key, default = MiqAlert.target_needs_realtime_capture?(target) ? [:capture_threshold_with_alerts, 1] : [:capture_threshold, 10]

    value = VMDB::Config.new("vmdb").config.fetch_path(:performance, key, target.class.base_model.to_s.underscore.to_sym) || default
    value = if value.kind_of?(Fixnum) # Default unit is minutes
              value.minutes.ago.utc
            else
              value.to_i_with_method.seconds.ago.utc unless value.nil?
            end
    value
  end

  #
  # Capture entry points
  #

  def self.perf_capture_health_check(zone)
    q_items = MiqQueue.select(:method_name, :created_on).order(:created_on)
              .where(:state       => "ready",
                     :role        => "ems_metrics_collector",
                     :method_name => %w(perf_capture perf_capture_realtime perf_capture_hourly perf_capture_historical),
                     :zone        => zone.name)
    items_by_interval = q_items.group_by(&:method_name)
    items_by_interval.reverse_merge!("perf_capture_realtime" => [], "perf_capture_hourly" => [], "perf_capture_historical" => [])
    items_by_interval.each do |method_name, items|
      interval = method_name.sub("perf_capture_", "")
      msg = "#{items.length} #{interval.inspect} captures on the queue for zone [#{zone.name}]"
      msg << " - oldest: [#{items.first.created_on.utc.iso8601}], recent: [#{items.last.created_on.utc.iso8601}]" if items.length > 0
      _log.info(msg)
    end
  end

  def self.calc_targets_by_rollup_parent(targets)
    # Collect realtime targets and group them by their rollup parent, e.g. {"EmsCluster:4"=>[Host:4], "EmsCluster:5"=>[Host:1, Host:2]}
    targets_by_rollup_parent = targets.inject({}) do |h, target|
      next(h) unless target.kind_of?(Host) && target.perf_capture_now?

      interval_name = perf_target_to_interval_name(target)
      next unless interval_name == "realtime"

      target.perf_rollup_parents(interval_name).to_a.compact.each do |parent|
        pkey = "#{parent.class}:#{parent.id}"
        h[pkey] ||= []
        h[pkey] << "#{target.class}:#{target.id}"
      end

      h
    end
    targets_by_rollup_parent
  end

  def self.calc_tasks_by_rollup_parent(targets_by_rollup_parent)
    task_end_time           = Time.now.utc.iso8601
    default_task_start_time = 1.hour.ago.utc.iso8601

    # Create a new task for each rollup parent
    tasks_by_rollup_parent = targets_by_rollup_parent.keys.inject({}) do |h, pkey|
      name = "Performance rollup for #{pkey}"
      prev_task = MiqTask.where(:identifier => pkey).order("id DESC").first
      task_start_time = prev_task ? prev_task.context_data[:end] : default_task_start_time

      task = MiqTask.create(
        :name         => name,
        :identifier   => pkey,
        :state        => MiqTask::STATE_QUEUED,
        :status       => MiqTask::STATUS_OK,
        :message      => "Task has been queued",
        :context_data => {
          :start    => task_start_time,
          :end      => task_end_time,
          :parent   => pkey,
          :targets  => targets_by_rollup_parent[pkey],
          :complete => [],
          :interval => "realtime"
        }
      )
      _log.info "Created task id: [#{task.id}] for: [#{pkey}] with targets: #{targets_by_rollup_parent[pkey].inspect} for time range: [#{task_start_time} - #{task_end_time}]"
      h[pkey] = task
      h
    end

    tasks_by_rollup_parent
  end

  def self.queue_captures(targets, targets_by_rollup_parent, tasks_by_rollup_parent)
    # Queue the captures for each target
    use_historical = historical_days != 0
    targets.each do |target|
      interval_name = perf_target_to_interval_name(target)

      options = {}
      target.perf_rollup_parents(interval_name).to_a.compact.each do |parent|
        if tasks_by_rollup_parent.key?("#{parent.class}:#{parent.id}")
          pkey = "#{parent.class}:#{parent.id}"
          tkey = "#{target.class}:#{target.id}"
          if targets_by_rollup_parent[pkey].include?(tkey)
            # FIXME: check that this is still correct
            options[:task_id] = tasks_by_rollup_parent[pkey].id
            options[:force]   = true # Force collection since we've already verified that capture should be done now
          end
        end
      end
      target.perf_capture_queue(interval_name, options)

      if !target.kind_of?(Storage) && use_historical && target.last_perf_capture_on.nil?
        target.perf_capture_queue('historical')
      end
    end
  end

  def self.perf_target_to_interval_name(target)
    case target
    when Host, VmOrTemplate then                       "realtime"
    when ContainerNode, Container, ContainerGroup then "realtime"
    when Storage then                                  "hourly"
    end
  end
end
