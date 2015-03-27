require 'workers/worker_base'
require 'workers/mixins/web_server_worker_mixin'

class UiWorker < WorkerBase
  include WebServerWorkerMixin
end
