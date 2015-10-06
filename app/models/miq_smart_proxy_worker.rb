class MiqSmartProxyWorker < MiqQueueWorkerBase
  require_dependency 'miq_smart_proxy_worker/runner'

  self.required_roles       = ["smartproxy"]
  self.default_queue_name   = "smartproxy"
end
