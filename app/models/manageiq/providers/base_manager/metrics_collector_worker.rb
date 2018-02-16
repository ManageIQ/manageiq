class ManageIQ::Providers::BaseManager::MetricsCollectorWorker < MiqQueueWorkerBase
  include MiqWorker::ReplicaPerWorker

  require_nested :Runner

  include PerEmsTypeWorkerMixin

  self.required_roles = ["ems_metrics_collector"]

  def self.supports_container?
    true
  end

  def self.normalized_type
    @normalized_type ||= "ems_metrics_collector_worker"
  end

  def self.ems_class
    parent
  end
end
