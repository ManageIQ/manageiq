class ManageIQ::Providers::Openstack::InfraManager::MetricsCollectorWorker < ::MiqEmsMetricsCollectorWorker
  require_dependency 'manageiq/providers/openstack/infra_manager/metrics_collector_worker/runner'

  self.default_queue_name = "openstack_infra"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for OpenstackInfra"
  end

  def self.ems_class
    ManageIQ::Providers::Openstack::InfraManager
  end
end
