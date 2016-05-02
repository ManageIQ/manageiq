class ManageIQ::Providers::Azure::CloudManager::MetricsCapture < ManageIQ::Providers::BaseManager::MetricsCapture
  def perf_collect_metrics(interval_name, start_time = nil, end_time = nil)
    raise "No EMS defined" if target.ext_management_system.nil?

    log_header = "[#{interval_name}] for: [#{target.class.name}], [#{target.id}], [#{target.name}]"

    # TODO: Actually collect the metrics
    _log.warn("#{log_header} Metrics not yet being collected.")
    return {}, {}
  end
end
