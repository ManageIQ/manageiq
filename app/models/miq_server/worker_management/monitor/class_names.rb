module MiqServer::WorkerManagement::Monitor::ClassNames
  extend ActiveSupport::Concern

  module ClassMethods
    def monitor_class_names
      MiqWorkerType.pluck(:worker_type)
    end

    def monitor_class_names_in_kill_order
      MiqWorkerType.in_kill_order.pluck(:worker_type)
    end
  end
end
