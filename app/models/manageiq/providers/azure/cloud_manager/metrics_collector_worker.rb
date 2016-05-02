class ManageIQ::Providers::Azure::CloudManager::MetricsCollectorWorker < ManageIQ::Providers::BaseManager::MetricsCollectorWorker
  require_nested :Runner

  self.default_queue_name = "azure"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for Azure"
  end
end
