require 'miq_server/worker_management_base'

module MiqServer::WorkerManagement
  extend ActiveSupport::Concern

  include_concern 'Dequeue'
  include_concern 'Heartbeat'
  include_concern 'Monitor'

  include MiqServerWorkerManagementBase
end
