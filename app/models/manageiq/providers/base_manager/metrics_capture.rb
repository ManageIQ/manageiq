class ManageIQ::Providers::BaseManager::MetricsCapture
  include Vmdb::Logging

  attr_reader :target, :ems
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

  # Capture all metrics for an ems
  def perf_capture
    perf_capture_health_check
    targets = Metric::Targets.capture_ems_targets(ems)

    targets_by_rollup_parent = calc_targets_by_rollup_parent(targets)
    target_options = calc_target_options(targets_by_rollup_parent)
    targets = filter_perf_capture_now(targets, target_options)
    queue_captures(targets, target_options)
  end

  # @param targets [Array<Object>] list of the targets for capture (from `capture_ems_targets`)
  # @param target_options [ Hash{Object => Hash{Symbol => Object}}] list of options indexed by target
  def queue_captures(targets, target_options)
    targets.each do |target|
      options = target_options[target] || {}
      interval_name = options[:interval] || perf_target_to_interval_name(target)
      target.perf_capture_queue(interval_name, options)
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

  def filter_perf_capture_now(targets, target_options)
    targets.select do |target|
      options = target_options[target]
      # [:force] is set if we already determined this target needs perf capture
      if options[:force] || perf_capture_now?(target)
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
        perf_capture_now?(target) &&
        target.ems_cluster_id
    end
    realtime_targets.group_by(&:ems_cluster)
  end

  # Determine queue options for each target
  # Is only generating options for Vmware Hosts, which have a task for rollups.
  # The rest just set the zone
  def calc_target_options(targets_by_rollup_parent)
    # Purge tasks older than 4 hours
    MiqTask.delete_older(4.hours.ago.utc, "name LIKE 'Performance rollup for %'")

    task_end_time           = Time.now.utc.iso8601
    default_task_start_time = 1.hour.ago.utc.iso8601

    target_options = Hash.new { |h, k| h[k] = {:zone => zone} }
    # Create a new task for each rollup parent
    # mark each target with the rollup parent
    targets_by_rollup_parent.each_with_object(target_options) do |(parent, targets), h|
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
        h[target] = {
          :task_id => task.id,
          :force   => true, # Force collection since we've already verified that capture should be done now
          :zone    => zone,
        }
      end
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
