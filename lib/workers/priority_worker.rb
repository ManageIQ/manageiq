require 'workers/queue_worker_base'

class PriorityWorker < QueueWorkerBase
  self.wait_for_worker_monitor = false
end
