class ManageIQ::Providers::Vmware::InfraManager::MetricsCollectorWorker < ManageIQ::Providers::BaseManager::MetricsCollectorWorker
  require_dependency 'manageiq/providers/vmware/infra_manager/metrics_collector_worker/runner'

  self.default_queue_name = "vmware"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for vCenter"
  end
end
