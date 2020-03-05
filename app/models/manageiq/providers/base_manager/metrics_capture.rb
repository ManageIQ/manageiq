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
    perf_capture_queue("realtime", :rollups => true)
  end

  def perf_capture_gap(start_time, end_time)
    @target = capture_ems_targets(:exclude_storages => true)
    perf_capture_queue('historical', :start_time => start_time.utc, :end_time => end_time.utc)
  end

  def perf_capture_realtime_queue
    perf_capture_queue('realtime')
  end

  def perf_capture_queue(interval, start_time: nil, end_time: nil, rollups: false)
    if interval == "realtime" && Metric::Capture.historical_days != 0
      historical_start = Metric::Capture.historical_start_time
      historical_end   = 1.day.from_now.utc.beginning_of_day
    end
    realtime_cut_off = 4.hours.ago.utc.beginning_of_day

    targets_by_class = Array(@target).group_by { |t| t.class.base_class.name }
    targets_by_class.each do |class_name, class_targets|
      class_interval = class_name == "Storage" ? "hourly" : interval

      if class_name == "Host" && rollups # implied: class_interval == realtime
        class_targets.group_by(&:ems_cluster).each do |ems_cluster, hosts|
          perf_capture_queue_targets(hosts, interval, :start_time => start_time, :end_time => end_time, :parent => ems_cluster)
        end
      elsif class_interval == "historical"
        perf_capture_queue_targets_hist(class_targets, class_interval, :start_time => start_time, :end_time => end_time)
      else
        perf_capture_queue_targets(class_targets, class_interval, :start_time => start_time, :end_time => end_time)
      end

      # handle scenarios that add historial captures to the realtime captures
      if class_interval == "realtime" # implied: class_name != "Storage"
        targets_already_captured, targets_not_captured = class_targets.partition(&:last_perf_capture_on)

        # targets with no captured metrics
        if historical_start
          perf_capture_queue_targets_hist(targets_not_captured, "historical", :start_time => historical_start, :end_time => historical_end)
        end

        # targets that haven't captured realtime metrics in a while
        # TODO: send these in batches instead of one offs (use split_capture_intervals logic to send 1 day at a time)
        # TODO: if it has been months, do we want a limit to the total time duration of these captures?
        gapped_targets = targets_already_captured.select { |t| t.last_perf_capture_on < realtime_cut_off }
        gapped_targets.each do |target|
          split_capture_intervals(target.last_perf_capture_on, realtime_cut_off).each do |s, e|
            perf_capture_queue_target(target, "historical", :start_time => s, :end_time => e)
          end
        end
      end
    end

    # Purge tasks older than 4 hours
    MiqTask.delete_older(4.hours.ago.utc, "name LIKE 'Performance rollup for %'") if rollups
  end

  def perf_capture_queue_targets_hist(targets, interval, start_time: nil, end_time: nil)
    split_capture_intervals(start_time, end_time).each do |st, ed|
      perf_capture_queue_targets(targets, interval, :start_time => st, :end_time => ed)
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

  def create_rollup_task_for_cluster(ems_cluster, hosts)
    return unless ems_cluster

    pkey = "#{ems_cluster.class.name}:#{ems_cluster.id}"
    prev_task = MiqTask.where(:identifier => pkey).order("id DESC").first
    task_start_time = prev_task ? prev_task.context_data[:end] : 1.hour.ago.utc.iso8601
    task_end_time = Time.now.utc.iso8601

    MiqTask.create(
      :name         => "Performance rollup for #{pkey}",
      :identifier   => pkey,
      :state        => MiqTask::STATE_QUEUED,
      :status       => MiqTask::STATUS_OK,
      :message      => "Task has been queued",
      :context_data => {
        :start    => task_start_time,
        :end      => task_end_time,
        :parent   => pkey,
        :targets  => hosts.map { |target| "#{target.class}:#{target.id}" },
        :complete => [],
        :interval => "realtime"
      }
    ).tap do |task|
      _log.info("Created task id: [#{task.id}] for: [#{pkey}] with targets: #{hosts.inspect} for time range: [#{task_start_time} - #{task_end_time}]")
    end
  end

  def perf_capture_queue_targets(targets, interval, start_time: nil, end_time: nil, parent: nil)
    task = create_rollup_task_for_cluster(parent, targets) if parent
    targets.each do |target|
      perf_capture_queue_target(target, interval, :start_time => start_time, :end_time => end_time, :task_id => task&.id)
    rescue => err
      _log.warn("Failed to queue perf_capture for target [#{target.class.name}], [#{target.id}], [#{target.name}]: #{err}")
    end
  end

  def perf_capture_queue_target(target, interval_name, start_time: nil, end_time: nil, task_id: nil)
    # cb is the task used to group cluster realtime metrics
    cb = {:class_name => target.class.name, :instance_id => target.id, :method_name => :perf_capture_callback, :args => [[task_id]]} if task_id

    # Queue up the actual items
    queue_item = {
      :class_name  => target.class.name,
      :method_name => "perf_capture_#{interval_name}",
      :priority    => Metric::Capture.interval_priority(interval_name),
      :instance_id => target.id,
      :role        => 'ems_metrics_collector',
      :queue_name  => ems.metrics_collector_queue_name,
      :zone        => my_zone,
      :state       => ['ready', 'dequeue'],
    }
    queue_item[:args] = [start_time, end_time] if start_time

    # reason for setting MiqQueue#miq_task_id is to initializes MiqTask.started_on column when message delivered.
    MiqQueue.create_with(:miq_task_id => task_id, :miq_callback => cb).put_or_update(queue_item) do |msg, qi|
      if msg.nil?
        qi.delete(:state)
        qi
      elsif msg.state == "ready" && task_id
        # rerun the job
        qi.delete(:state)
        existing_tasks = ((msg.miq_callback || {})[:args] || []).first || []
        qi[:miq_callback] = cb.merge(:args => [existing_tasks + [task_id]])
        qi
      else
        _log.debug("Skipping capture of #{target.log_target} - Performance capture for interval #{interval_name} is still running")
        # NOTE: do not update the message queue
        nil
      end
    end
  end

  # split capture interval for historical queue captures (so the fetch is not too big)
  # an array of ordered pairs from start_time to end_time partitioned by each day. (most recent day first / reverse chronological)
  #
  # example:
  #
  #  start_time = 2017/01/01 12:00:00, end_time = 2017/01/04 12:00:00
  #  [[2017-01-03 12:00:00 UTC, 2017-01-04 12:00:00 UTC],
  #   [2017-01-02 12:00:00 UTC, 2017-01-03 12:00:00 UTC],
  #   [2017-01-01 12:00:00 UTC, 2017-01-02 12:00:00 UTC]]
  def split_capture_intervals(start_time = nil, end_time = nil, threshold = 1.day)
    return [] unless start_time

    (start_time.utc..end_time.utc).step_value(threshold).each_cons(2).collect do |s_time, e_time|
      [s_time, e_time]
    end.reverse
  end
end
