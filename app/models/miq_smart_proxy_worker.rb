class MiqSmartProxyWorker < MiqQueueWorkerBase
  include MiqWorker::ReplicaPerWorker

  require_nested :Runner

  self.required_roles       = ["smartproxy"]
  self.default_queue_name   = "smartproxy"

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_SMART_PROXY_WORKERS
  end
end
