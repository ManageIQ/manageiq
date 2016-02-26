class ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker < ManageIQ::Providers::BaseManager::MetricsCollectorWorker
  require_nested :Runner

  self.default_queue_name = "amazon"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for Amazon"
  end
end
