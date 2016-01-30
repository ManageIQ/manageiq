class ManageIQ::Providers::Redhat::InfraManager::MetricsCollectorWorker < ManageIQ::Providers::BaseManager::MetricsCollectorWorker
  require_nested :Runner
  self.default_queue_name = "redhat"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for RHEV"
  end
end
