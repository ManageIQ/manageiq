module Metric::Capture
  VALID_CAPTURE_INTERVALS = ['realtime', 'hourly', 'historical'].freeze

  # This is nominally a VMware-specific value, but we currently expect
  # all providers to conform to it.
  REALTIME_METRICS_PER_MINUTE = 3

  REALTIME_PRIORITY = HOURLY_PRIORITY = DAILY_PRIORITY = MiqQueue::NORMAL_PRIORITY
  HISTORICAL_PRIORITY = MiqQueue::LOW_PRIORITY

  def self.capture_cols
    @capture_cols ||= Metric.columns_hash.collect { |c, h| c.to_sym if h.type == :float && c[0, 7] != "derived" }.compact
  end

  def self.historical_days
    Settings.performance.history.initial_capture_days.to_i
  end

  def self.historical_start_time
    historical_days.days.ago.utc.beginning_of_day
  end

  def self.targets_archived_from
    archived_for_setting = Settings.performance.targets.archived_for
    archived_for_setting.to_i_with_method.seconds.ago.utc
  end

  def self.concurrent_requests(interval_name)
    requests = ::Settings.performance.concurrent_requests[interval_name]
    requests = 20 if requests < 20 && interval_name == 'realtime'
    requests
  end

  # legacy messages on the queue
  # went away in 4.6
  def self.perf_capture_timer(zone = nil)
  end

  def self.perf_collect_all_metrics_queue(emses, interval_name = "realtime", start_time = nil, end_time = nil, options = {})
    emses.each do |ems|
      MiqQueue.put_unless_exists(
        :class_name  => "Metric::Capture",
        :method_name => "perf_collect_all_metrics",
        :args        => [ems.id, interval_name, start_time, end_time, options],
        :role        => "ems_metrics_collector",
        :queue_name  => ems.metrics_collector_queue_name,
        :zone        => ems.zone_name,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :state       => %w(ready dequeue),
      )
    end
  end

  def self.perf_collect_all_metrics(ems, interval_name = "realtime", start_time = nil, end_time = nil, options = {})
    ems = ExtManagementSystem.find(ems) unless ems.kind_of?(ExtManagementSystem)
    klass = ems.class::MetricsCapture
    klass.new(nil, ems).perf_collect_all_metrics(interval_name, start_time, end_time, options)
  end

  def self.perf_capture_gap(start_time, end_time, zone_id = nil)
    perf_capture_gap_queue(start_time, end_time, zone_id)
  end

  # called by ui
  # run a perf capture zone for a zone or ems
  # @param zone_or_ems [Zone, Integer, ExtManagementSystem] Legacy passes zone (or zone_id), but we're moving to ems
  def self.perf_capture_gap_queue(start_time, end_time, zone_or_ems = nil)
    emses = if zone_or_ems.kind_of?(ExtManagementSystem)
              [zone_or_ems]
            else
              zone_or_ems = Zone.find(zone_or_ems) if zone_or_ems && !zone_or_ems.kind_of?(Zone)
              zone_or_ems ||= MiqServer.my_server(true).zone
              zone_or_ems.ext_management_systems
            end
    perf_collect_all_metrics_queue(emses, "historical", start_time, end_time, :exclude_storages => true)
  end
end
