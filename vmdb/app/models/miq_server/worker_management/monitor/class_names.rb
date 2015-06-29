module MiqServer::WorkerManagement::Monitor::ClassNames
  extend ActiveSupport::Concern

  MONITOR_CLASS_NAMES = %w{
    MiqEmsMetricsCollectorWorkerAmazon
    MiqEmsMetricsCollectorWorkerRedhat
    ManageIQ::Providers::Vmware::InfraManager::MetricsCollectorWorker
    MiqEmsMetricsCollectorWorkerOpenstack
    MiqEmsMetricsCollectorWorkerOpenstackInfra
    MiqEmsMetricsProcessorWorker
    MiqEmsRefreshCoreWorker
    MiqEmsRefreshWorkerAmazon
    MiqEmsRefreshWorkerForemanConfiguration
    MiqEmsRefreshWorkerForemanProvisioning
    MiqEmsRefreshWorkerKubernetes
    MiqEmsRefreshWorkerOpenshift
    MiqEmsRefreshWorkerMicrosoft
    MiqEmsRefreshWorkerRedhat
    MiqEmsRefreshWorkerOpenstack
    MiqEmsRefreshWorkerOpenstackInfra
    ManageIQ::Providers::Vmware::InfraManager::RefreshWorker
    MiqEventCatcherAmazon
    MiqEventCatcherKubernetes
    MiqEventCatcherOpenshift
    MiqEventCatcherRedhat
    MiqEventCatcherOpenstack
    MiqEventCatcherOpenstackInfra
    ManageIQ::Providers::Vmware::InfraManager::EventCatcher
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
    MiqAutomateWorker
  }.freeze

  MONITOR_CLASS_NAMES_IN_KILL_ORDER = %w{
    MiqAutomateWorker
    MiqEmsMetricsProcessorWorker
    MiqEmsMetricsCollectorWorkerAmazon
    MiqEmsMetricsCollectorWorkerRedhat
    ManageIQ::Providers::Vmware::InfraManager::MetricsCollectorWorker
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
    MiqEmsRefreshWorkerForemanConfiguration
    MiqEmsRefreshWorkerForemanProvisioning
    MiqEmsRefreshWorkerKubernetes
    MiqEmsRefreshWorkerOpenshift
    MiqEmsRefreshWorkerMicrosoft
    MiqEmsRefreshWorkerRedhat
    MiqEmsRefreshWorkerOpenstack
    MiqEmsRefreshWorkerOpenstackInfra
    ManageIQ::Providers::Vmware::InfraManager::RefreshWorker
    MiqScheduleWorker
    MiqPriorityWorker
    MiqWebServiceWorker
    MiqEmsRefreshCoreWorker
    MiqVimBrokerWorker
    ManageIQ::Providers::Vmware::InfraManager::EventCatcher
    MiqEventCatcherRedhat
    MiqEventCatcherOpenstack
    MiqEventCatcherOpenstackInfra
    MiqEventCatcherAmazon
    MiqEventCatcherKubernetes
    MiqEventCatcherOpenshift
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
