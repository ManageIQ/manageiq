class MiqSmartProxyWorker < MiqQueueWorkerBase
  require_nested :Runner

  self.required_roles       = ["smartproxy"]
  self.default_queue_name   = "smartproxy"

  def self.kill_priority
    40
  end
end
