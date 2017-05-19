require "workers/miq_worker_types"

module MiqServer::WorkerManagement::Monitor::ClassNames
  extend ActiveSupport::Concern

  MONITOR_CLASS_NAMES               = MIQ_WORKER_TYPES
  MONITOR_CLASS_NAMES_IN_KILL_ORDER = MIQ_WORKER_TYPES_IN_KILL_ORDER

  module ClassMethods
    def monitor_class_names
      MONITOR_CLASS_NAMES
    end

    def monitor_class_names_in_kill_order
      MONITOR_CLASS_NAMES_IN_KILL_ORDER
    end
  end
end
