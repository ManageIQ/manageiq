class ManageIQ::Providers::Azure::NetworkManager::MetricsCollectorWorker < ::MiqEmsMetricsCollectorWorker
  self.default_queue_name = "azure_network"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for Azure Network"
  end

  def self.ems_class
    ManageIQ::Providers::Azure::NetworkManager
  end

  def self.settings_name
    :ems_metrics_collector_worker_azure_network
  end
end
