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

  # Determine queue options for each target
  # Is only generating options for Vmware Hosts, which have a task for rollups.
  # The rest just set the zone
  def calc_target_options(targets_by_rollup_parent)
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
