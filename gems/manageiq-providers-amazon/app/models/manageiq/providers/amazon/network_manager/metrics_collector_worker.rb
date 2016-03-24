class ManageIQ::Providers::Amazon::NetworkManager::MetricsCollectorWorker < ::MiqEmsMetricsCollectorWorker
  require_nested :Runner

  self.default_queue_name = "amazon_network"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for Amazon Network"
  end

  def self.ems_class
    ManageIQ::Providers::Amazon::NetworkManager
  end

  def self.settings_name
    :ems_metrics_collector_worker_amazon_network
  end
end
