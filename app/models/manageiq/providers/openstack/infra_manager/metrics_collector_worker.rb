class ManageIQ::Providers::Openstack::InfraManager::MetricsCollectorWorker < ::MiqEmsMetricsCollectorWorker
  require_nested :Runner

  self.default_queue_name = "openstack_infra"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for OpenstackInfra"
  end

  def self.ems_class
    ManageIQ::Providers::Openstack::InfraManager
  end

  def self.settings_name
    :ems_metrics_collector_worker_openstack_infra
  end
end
