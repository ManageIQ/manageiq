class MiqSmartProxyWorker < MiqQueueWorkerBase
  require_nested :Runner

  self.required_roles       = ["smartproxy"]
  self.default_queue_name   = "smartproxy"
end
