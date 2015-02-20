module MiqServer::WorkerManagement::Monitor::ClassNames
  extend ActiveSupport::Concern

  MONITOR_CLASS_NAMES = %w{
    MiqEmsMetricsCollectorWorkerAmazon
    MiqEmsMetricsCollectorWorkerRedhat
    MiqEmsMetricsCollectorWorkerVmware
    MiqEmsMetricsCollectorWorkerOpenstack
    MiqEmsMetricsCollectorWorkerOpenstackInfra
    MiqEmsMetricsProcessorWorker
    MiqEmsRefreshCoreWorker
    MiqEmsRefreshWorkerAmazon
    MiqEmsRefreshWorkerMicrosoft
    MiqEmsRefreshWorkerRedhat
    MiqEmsRefreshWorkerOpenstack
    MiqEmsRefreshWorkerOpenstackInfra
    MiqEmsRefreshWorkerVmware
    MiqEventCatcherAmazon
    MiqEventCatcherRedhat
    MiqEventCatcherOpenstack
    MiqEventCatcherOpenstackInfra
    MiqEventCatcherVmware
    MiqEventHandler
    MiqGenericWorker
    MiqNetappRefreshWorker
    MiqPriorityWorker
    MiqReplicationWorker
    MiqReportingWorker
    MiqScheduleWorker
    MiqSmartProxyWorker
    MiqSmisRefreshWorker
    MiqStorageMetricsCollectorWorker
    MiqUiWorker
    MiqVimBrokerWorker
    MiqVmdbStorageBridgeWorker
    MiqWebServiceWorker
  }.freeze

  MONITOR_CLASS_NAMES_IN_KILL_ORDER = %w{
    MiqEmsMetricsProcessorWorker
    MiqEmsMetricsCollectorWorkerAmazon
    MiqEmsMetricsCollectorWorkerRedhat
    MiqEmsMetricsCollectorWorkerVmware
    MiqEmsMetricsCollectorWorkerOpenstack
    MiqEmsMetricsCollectorWorkerOpenstackInfra
    MiqReportingWorker
    MiqSmartProxyWorker
    MiqReplicationWorker
    MiqGenericWorker
    MiqEventHandler
    MiqSmisRefreshWorker
    MiqNetappRefreshWorker
    MiqVmdbStorageBridgeWorker
    MiqStorageMetricsCollectorWorker
    MiqEmsRefreshWorkerAmazon
    MiqEmsRefreshWorkerMicrosoft
    MiqEmsRefreshWorkerRedhat
    MiqEmsRefreshWorkerOpenstack
    MiqEmsRefreshWorkerOpenstackInfra
    MiqEmsRefreshWorkerVmware
    MiqScheduleWorker
    MiqPriorityWorker
    MiqWebServiceWorker
    MiqEmsRefreshCoreWorker
    MiqVimBrokerWorker
    MiqEventCatcherVmware
    MiqEventCatcherRedhat
    MiqEventCatcherOpenstack
    MiqEventCatcherOpenstackInfra
    MiqEventCatcherAmazon
    MiqUiWorker
  }.freeze

  module ClassMethods
    def monitor_class_names
      MONITOR_CLASS_NAMES
    end

    def monitor_class_names_in_kill_order
      MONITOR_CLASS_NAMES_IN_KILL_ORDER
    end
  end

end
