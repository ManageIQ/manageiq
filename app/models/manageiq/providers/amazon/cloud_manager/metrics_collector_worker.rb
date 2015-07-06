class ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker < ManageIQ::Providers::BaseManager::MetricsCollectorWorker
  require_dependency 'manageiq/providers/amazon/cloud_manager/metrics_collector_worker/runner'

  self.default_queue_name = "amazon"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for Amazon"
  end
end
