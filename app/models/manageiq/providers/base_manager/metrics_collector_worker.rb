class ManageIQ::Providers::BaseManager::MetricsCollectorWorker < MiqWorker
  require_nested :Runner

  include PerEmsWorkerMixin

  self.required_roles = ["ems_metrics_collector"]

  def self.normalized_type
    @normalized_type ||= "ems_metrics_collector_worker"
  end

  def self.ems_class
    parent
  end
end
