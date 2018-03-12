class ManageIQ::Providers::BaseManager::MetricsCapture
  HOURLY_METRICS_DURATION = 4.hours
  include Vmdb::Logging

  attr_reader :target, :ems
  def initialize(target, ems = nil)
    @target = target
    @ems    = ems
  end

  # New method to collect metrics. It is ems centric
  # It collects all metrics that are enabled
  # option options :exclude_storages [Boolean] if true, will not include storages
  def perf_collect_all_metrics(interval_name, start_time = nil, end_time = nil, options = {})
    grouped_targets(ems, options).each do |target_class, targets|
      case target_class
      when "Storage"
        perf_collect_storages(targets, interval_name, start_time, end_time)
      when "Host"
        perf_collect_hosts(targets, interval_name, start_time, end_time)
      else
        perf_collect_targets(targets, interval_name, start_time, end_time)
      end
    end
    self
  end

  private

  # Determine possible collection targets grouped by target type (base class name)
  #
  # @param [ExtManagementSystem] ems
  # @options options [Boolean] :skip_storage Skip collection of storages - used for gap collection
  # @raises "Unknown ems type" if the ems is not infra, cloud, or container
  def grouped_targets(ems, options = {})
    all_capture_targets(ems, options).group_by { |t| t.class.base_class.name }
  end

  # Determine targets for an ems
  #
  # @param [ExtManagementSystem] ems
  # @options options [Boolean] :skip_storage Skip collection of storages - used for gap collection
  #
  def all_capture_targets(ems, options = {})
    if ems.kind_of?(::ManageIQ::Providers::InfraManager)
      Metric::Targets.capture_infra_targets([ems], options)
    elsif ems.kind_of?(::ManageIQ::Providers::CloudManager)
      Metric::Targets.capture_cloud_targets([ems], options)
    elsif ems.kind_of?(::ManageIQ::Providers::ContainerManager)
      Metric::Targets.capture_container_targets([ems], options)
    else
      raise "Unknown ems type #{ems.class.name}"
    end
  end

  def perf_collect_storages(targets, interval_name, start_time, end_time)
    capture_interval = %w(realtime historical).include?(interval_name) ? "hourly" : interval_name
    targets.each do |target|
      # NOTE: storage is not fetched from provider
      #       Storage#perf_capture is really just perf_process
      capture_start, capture_end = fix_capture_start_end_time(interval_name, target, start_time, end_time)
      perf_process_queue(target, "perf_capture_#{capture_interval}", capture_interval, capture_start, capture_end)
    end
  end

  def perf_collect_hosts(targets, interval_name, start_time, end_time)
    # assuming there are fewer than $query_size hosts per cluster - (typically is is < 40)
    targets.group_by(&:ems_cluster_id).each do |parent_id, targets_in_cluster|
      start_range, end_range, counters_data = capture_targets(targets_in_cluster, interval_name, start_time, end_time)
      perf_process_queue(ems, "perf_process", interval_name, start_range, end_range, counters_data, parent_id)
    end
  end

  def perf_collect_targets(targets, interval_name, start_time, end_time)
    query_size = Metric::Capture.concurrent_requests(interval_name)
    targets.each_slice(query_size).each do |target_group|
      start_range, end_range, counters_data = capture_targets(target_group, interval_name, start_time, end_time)
      perf_process_queue(ems, "perf_process", interval_name, start_range, end_range, counters_data)
    end
  end

  # Perform capture on list of targets
  # @param targets [Array<Object>] array of targets to be captured
  # @param start_time [String, nil] Start time - typically nil. has value for gap collection
  # @param end_time   [String, nil] Ending time - typically nil. has value for gap collection
  # [{
  #   :ems_id         => ems_id,         # "2"
  #   :ems_ref        => target.ems_ref, # "vm-55"
  #   :ems_klass      => ("Vm", "Host", "Storage")
  #   :interval_name  => ("realtime", "hourly")
  #   :start_range    => start_time,
  #   :end_range      => end_time,
  #   :counters       => {
  #     "#{counter_id}_#{instance}" => { # e.g.: "143_" =>
  #         :counter_key           => :"#{group}_#{name}_#{stats}_#{rollup}", # :net_usage_rate_average
  #         :rollup                => ("realtime", ...)
  #         :precision             => (0.1, 1),
  #         :unit_key              => ("percent", "kiloBytesPerSecond"),
  #         :vim_key               => counter_id, # "143"
  #         :instance              => instance,   # ""
  #         :capture_interval      => interval,   # "20"
  #         :capture_interval_name => ("realtime", "hourly"),
  #       }
  #   },
  #   :counter_values => {
  #     timestamp => {                           # "2017-09-25T19:55:20Z"
  #       "#{counter_id}_#{instance}" => Numeric # "143_" => 0
  #     }
  #   }
  # }]
  # @return [Array<Hash{Symbol=>Integer,String,Array<String>,Hash{String=>Float}}>

  def capture_targets(targets, interval_name, start_time, end_time)
    all_start_range  = nil
    all_end_range    = nil
    all_counter_data = {}
    targets.each do |target|
      begin
        capture_start, capture_end = fix_capture_start_end_time(interval_name, target, start_time, end_time)

        if interval_name == "realtime"
          # TODO: do proper rounding.
          # ? is end_time
          # ? pass in start or object.last_perf_capture_on
          # ? what is the end of the historical - is it 4 hours ago? is it end_time?
          gap_start, gap_end = fix_capture_start_end_time("historical", target, nil, capture_start || end_time)
          if (gap_start && gap_start < gap_end)
            start_range, end_range, counter_data = perf_capture_one(target, "historical", gap_start, gap_end)
            if counter_data
              all_counter_data.merge!(counter_data)
              all_start_range = start_range if all_start_range.nil? || all_start_range > start_range
              all_end_range = end_range if all_end_range.nil? || all_end_range < end_range
            end
          end
        end

        start_range, end_range, counter_data = perf_capture_one(target, interval_name, capture_start, capture_end)
        if counter_data
          all_counter_data.merge!(counter_data)
          all_start_range = start_range if all_start_range.nil? || all_start_range > start_range
          all_end_range = end_range if all_end_range.nil? || all_end_range < end_range
        end
      rescue => e
        _log.warn("Issue capturing metrics for #{target.class.name}:#{target.id} skipping: #{e.message}")
      end
    end

    [all_start_range, all_end_range, all_counter_data]
  end

  # this method is used for tests
  # It gives us an easy point to verify perf_capture requests were made.
  def perf_capture_one(target, interval_name, start_time, end_time)
    target.just_perf_capture(interval_name, start_time, end_time)
  end

  def fix_capture_start_end_time(interval_name, object = nil, start_time = nil, end_time = nil)
    start_time = start_time.utc unless start_time.nil?
    end_time = end_time.utc unless end_time.nil?

    # Determine the start_time for capturing if not provided
    if interval_name == 'historical' || interval_name == 'hourly'
      start_time ||= object.last_perf_capture_on if object
      # For hourly on the first capture, we don't want to get all of the
      #   historical data, so we shorten the query
      start_time ||= Metric::Capture.historical_start_time
    elsif object
      start_time ||= object.last_perf_capture_on
    else
      start_time ||= ems.last_metrics_success_date
    end

    if interval_name == 'realtime' && (start_time.nil? || start_time < HOURLY_METRICS_DURATION.ago.utc)
      start_time = HOURLY_METRICS_DURATION.ago.utc
    end
    [start_time, end_time]
  end

  def detect_gap(interval_name)
    if interval_name == "realtime" && ems.last_metrics_success_date.nil?
      gap_start_time, gap_end_time = fix_capture_start_end_time("historical", nil, nil, HOURLY_METRICS_DURATION.ago.utc)
      ::Metric::Capture.perf_capture_gap_queue(gap_start_time, gap_end_time, ems)
    end
  end

  # queue perf processing.
  # @param target [ExtManagementSystem, Storage] the object that receives the message.
  # @param method_name [String] "perf_process" for all but Storage, it uses "perf_capture_*"
  # @param interval_name [String]
  # @param rollup_id [String] The EmsCluster id if this is a Host and a rollup record is to be generated
  def perf_process_queue(target, method_name, interval_name, start_time, end_time, counters_data = nil, rollup_id = nil)
    if rollup_id
      miq_callback = {
        :class_name  => "EmsCluster",
        :instance_id => rollup_id,
        :method_name => "perf_rollup_range_cb",
        :zone        => ems.zone_name,
        :role        => 'ems_metrics_processor',
        :queue_name  => 'ems_metrics_processor',
        :args        => [start_time, end_time, interval_name, nil]
      }
    end
    MiqQueue.put(
      :class_name   => target.class.name,
      :method_name  => method_name,
      :instance_id  => target.id,
      :zone         => ems.zone_name,
      :role         => 'ems_metrics_processor',
      :queue_name   => 'ems_metrics_processor',
      :priority     => MiqQueue::NORMAL_PRIORITY,
      :args         => [interval_name, start_time, end_time],
      :data         => counters_data,
      :miq_callback => miq_callback
    )
  end
end
