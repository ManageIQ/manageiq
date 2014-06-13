require 'workers/ems_metrics_collector_worker'

class EmsMetricsCollectorWorkerVmware < EmsMetricsCollectorWorker
  self.require_vim_broker = true
end
