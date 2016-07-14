class ManageIQ::Providers::Google::NetworkManager::MetricsCollectorWorker < ::MiqEmsMetricsCollectorWorker
  self.default_queue_name = "google_network"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for Google Network"
  end

  def self.ems_class
    ManageIQ::Providers::Google::NetworkManager
  end

  def self.settings_name
    :ems_metrics_collector_worker_google_network
  end
end
