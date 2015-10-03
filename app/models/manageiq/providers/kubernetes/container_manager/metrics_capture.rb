module ManageIQ::Providers
  class Kubernetes::ContainerManager::MetricsCapture < BaseManager::MetricsCapture
    def perf_collect_metrics(interval_name, start_time = nil, end_time = nil)
      target_name = "#{target.class.name.demodulize}(#{target.id})"
      _log.info("Collecting metrics for #{target_name} [#{interval_name}] " \
                "[#{start_time}] [#{end_time}]")
      [{target.ems_ref => {}}, {target.ems_ref => {}}]
    end
  end
end
