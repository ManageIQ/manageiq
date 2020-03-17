class ManageIQ::Providers::BaseManager::MetricsCapture
  include Vmdb::Logging

  attr_reader :target, :ems

  # @param target [Array[Host,Vm],Vm,Host] object(s) that needs perf capture
  def initialize(target, ems = nil)
    @target = target
    @ems = ems
  end

  def zone
    ems.zone
  end

  def my_zone
    ems.zone.name
  end

  # Queue Capturing all metrics for an ems
  def perf_capture_all_queue
    perf_capture_health_check
    @target = filter_perf_capture_now(capture_ems_targets)
    perf_capture_queue(:rollups => true)
  end

  def perf_capture_gap(start_time, end_time)
    @target = capture_ems_targets(:exclude_storages => true)
    perf_capture_queue('historical', :start_time => start_time.utc, :end_time => end_time.utc)
  end

  def perf_capture_realtime_queue
    perf_capture_queue('realtime')
  end

  def perf_capture_queue(interval = nil, start_time: nil, end_time: nil, rollups: false)
    targets = Array(@target)
    target_options = rollups ? calc_target_options(targets) : {}

    targets.each do |target|
      task_id = target_options[target]
      perf_capture_queue_target(target, interval || perf_target_to_interval_name(target),
                                :start_time => start_time,
                                :end_time   => end_time,
                                :task_id    => task_id)
    rescue => err
      _log.warn("Failed to queue perf_capture for target [#{target.class.name}], [#{target.id}], [#{target.name}]: #{err}")
    end
  end

  private

  def perf_capture_health_check
    q_items = MiqQueue.select(:method_name, :created_on).order(:created_on)
                      .where(:state       => "ready",
                             :role        => "ems_metrics_collector",
                             :method_name => %w[perf_capture perf_capture_realtime perf_capture_hourly perf_capture_historical],
                             :zone        => my_zone)
    items_by_interval = q_items.group_by(&:method_name)
    items_by_interval.reverse_merge!("perf_capture_realtime" => [], "perf_capture_hourly" => [], "perf_capture_historical" => [])
    items_by_interval.each do |method_name, items|
      interval = method_name.sub("perf_capture_", "")
      msg = "#{items.length} #{interval.inspect} captures on the queue for zone [#{my_zone}]"
      msg << " - oldest: [#{items.first.created_on.utc.iso8601}], recent: [#{items.last.created_on.utc.iso8601}]" if items.present?
      _log.info(msg)
    end
  end

  def filter_perf_capture_now(targets)
    targets.select do |target|
      if perf_capture_now?(target)
        true
      else
        _log.debug do
          "Skipping capture of #{target.log_target} -" +
            "Performance last captured on [#{target.last_perf_capture_on}] is within threshold"
        end
        false
      end
    end
  end

  def capture_ems_targets(options = {})
    raise(NotImplementedError, _("must be implemented in subclass"))
  end

  # if it has not been run, or it was a very long time ago, just run it
  # if it has been run very recently (even too recently for realtime) then skip it
  # otherwise, it needs to be run if it is realtime, but not if it is standard threshold
  # assumes alert capture threshold <= standard capture threshold
  def perf_capture_now?(target)
    return true  if target.last_perf_capture_on.nil?
    return true  if target.last_perf_capture_on < Metric::Capture.standard_capture_threshold(target)
    return false if target.last_perf_capture_on >= Metric::Capture.alert_capture_threshold(target)

    MiqAlert.target_needs_realtime_capture?(target)
  end

  # Collect realtime targets and group them by their rollup parent
  #
  # 1. Only calculate rollups for Hosts
  # 2. Some Hosts have an EmsCluster as a parent, others have none.
  # 3. Only Hosts with a parent are rolled up.
  # 4. Only used for VMWare
  # @param [Array<Host|VmOrTemplate|Storage>] @targets The nodes to rollup
  # @returns Hash<String,Array<Host>>
  #   e.g.: {EmsCluster:4=>[Host:4], EmsCluster:5=>[Host:1, Host:2]}
  def calc_targets_by_rollup_parent(targets)
    realtime_targets = targets.select do |target|
      target.kind_of?(Host) &&
        target.ems_cluster_id
    end
    realtime_targets.group_by(&:ems_cluster)
  end

  # Determine queue options for each target
  # Is only generating options for Vmware Hosts, which have a task for rollups.
  # The rest just set the zone
  def calc_target_options(all_targets)
    targets_by_rollup_parent = calc_targets_by_rollup_parent(all_targets)
    # Purge tasks older than 4 hours
    MiqTask.delete_older(4.hours.ago.utc, "name LIKE 'Performance rollup for %'")

    task_end_time           = Time.now.utc.iso8601
    default_task_start_time = 1.hour.ago.utc.iso8601

    # Create a new task for each rollup parent
    # mark each target with the rollup parent
    targets_by_rollup_parent.each_with_object({}) do |(parent, targets), h|
      pkey = "#{parent.class.name}:#{parent.id}"
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
          :targets  => targets.map { |target| "#{target.class}:#{target.id}" },
          :complete => [],
          :interval => "realtime"
        }
      )
      _log.info("Created task id: [#{task.id}] for: [#{pkey}] with targets: #{targets_by_rollup_parent[pkey].inspect} for time range: [#{task_start_time} - #{task_end_time}]")
      targets.each do |target|
        h[target] = task.id
      end
    end
  end

  def perf_capture_queue_target(target, interval_name, start_time: nil, end_time: nil, task_id: nil)
    # cb is the task used to group cluster realtime metrics
    cb = {:class_name => target.class.name, :instance_id => target.id, :method_name => :perf_capture_callback, :args => [[task_id]]} if task_id && interval_name == 'realtime'
    items = queue_items_for_interval(target, interval_name, start_time, end_time)

    # Queue up the actual items
    queue_item = {
      :class_name  => target.class.name,
      :instance_id => target.id,
      :role        => 'ems_metrics_collector',
      :queue_name  => ems.metrics_collector_queue_name,
      :zone        => my_zone,
      :state       => ['ready', 'dequeue'],
    }

    messages = MiqQueue.where.not(:method_name => 'perf_capture_realtime').where(queue_item).index_by(&:args)
    items.each do |item_interval, *start_and_end_time|
      # Should both interval name and args (dates) be part of uniqueness query?
      queue_item_options = queue_item.merge(:method_name => "perf_capture_#{item_interval}")
      queue_item_options[:args] = start_and_end_time if start_and_end_time.present?
      next if item_interval != 'realtime' && messages[start_and_end_time]

      MiqQueue.put_or_update(queue_item_options) do |msg, qi|
        # reason for setting MiqQueue#miq_task_id is to initializes MiqTask.started_on column when message delivered.
        qi[:miq_task_id] = task_id if task_id && item_interval == "realtime"
        if msg.nil?
          qi[:priority] = Metric::Capture.interval_priority(item_interval)
          qi.delete(:state)
          if cb && item_interval == "realtime"
            qi[:miq_callback] = cb
          end
          qi
        elsif msg.state == "ready" && task_id && item_interval == "realtime"
          # rerun the job
          qi.delete(:state)
          existing_tasks = ((msg.miq_callback || {})[:args] || []).first || []
          qi[:miq_callback] = cb.merge(:args => [existing_tasks + [task_id]])
          qi
        else
          interval = qi[:method_name].sub("perf_capture_", "")
          _log.debug("Skipping capture of #{target.log_target} - Performance capture for interval #{interval} is still running")
          # NOTE: do not update the message queue
          nil
        end
      end
    end
  end

  # split capture interval for historical queue captures (so the fetch is not too big)
  # an array of ordered pairs from start_time to end_time partitioned by each day. (most recent day first / reverse chronological)
  #
  # example:
  #
  #  start_time = 2017/01/01 12:00:00, end_time = 2017/01/04 12:00:00
  #  [[interval_name, 2017-01-03 12:00:00 UTC, 2017-01-04 12:00:00 UTC],
  #   [interval_name, 2017-01-02 12:00:00 UTC, 2017-01-03 12:00:00 UTC],
  #   [interval_name, 2017-01-01 12:00:00 UTC, 2017-01-02 12:00:00 UTC]]
  def split_capture_intervals(interval_name, start_time = nil, end_time = nil, threshold = 1.day)
    return [] unless start_time

    (start_time.utc..end_time.utc).step_value(threshold).each_cons(2).collect do |s_time, e_time|
      [interval_name, s_time, e_time]
    end.reverse
  end

  # Note: default values are also derived in ci_mixin/capture.rb#fix_capture_start_end_time
  # @return realtime_interval, realtime_date, historical_start, historical_end
  def queue_items_for_interval(target, interval_name, start_time, end_time)
    # if last_perf_capture_on is nil (initial refresh), also go back historically
    # if last_perf_capture_on is earlier than 4.hour.ago.beginning_of_day,
    # then create *one* realtime capture for start_time = 4.hours.ago.beginning_of_day (no end_time)
    # and create historical captures for each day from last_perf_capture_on until 4.hours.ago.beginning_of_day
    if interval_name == 'historical'
      split_capture_intervals("historical", start_time, end_time)
    elsif interval_name == "hourly"
      [["hourly"]]
    else
      [["realtime"]] + split_capture_intervals("historical", *historical_dates(target.last_perf_capture_on))
    end
  end

  def historical_dates(last_perf_capture_on)
    realtime_cut_off = 4.hours.ago.utc.beginning_of_day

    if last_perf_capture_on.nil? && Metric::Capture.historical_days != 0
      [Metric::Capture.historical_start_time, 1.day.from_now.utc.beginning_of_day]
    elsif last_perf_capture_on && last_perf_capture_on < realtime_cut_off
      [last_perf_capture_on, realtime_cut_off]
    else
      []
    end
  end

  def perf_target_to_interval_name(target)
    case target
    when Host, VmOrTemplate then                       "realtime"
    when ContainerNode, Container, ContainerGroup then "realtime"
    when Storage then                                  "hourly"
    end
  end
end
