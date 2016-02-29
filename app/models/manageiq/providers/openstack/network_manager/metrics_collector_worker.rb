class ManageIQ::Providers::Openstack::NetworkManager::MetricsCollectorWorker < ::MiqEmsMetricsCollectorWorker
  require_nested :Runner

  self.default_queue_name = "openstack_network"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for Openstack Network"
  end

  def self.ems_class
    ManageIQ::Providers::Openstack::NetworkManager
  end

  def self.settings_name
    :ems_metrics_collector_worker_openstack_network
  end
end
