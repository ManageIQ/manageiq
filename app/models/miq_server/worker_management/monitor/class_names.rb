module MiqServer::WorkerManagement::Monitor::ClassNames
  extend ActiveSupport::Concern

  MONITOR_CLASS_NAMES = %w{
    ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker
    ManageIQ::Providers::Redhat::InfraManager::MetricsCollectorWorker
    ManageIQ::Providers::Vmware::InfraManager::MetricsCollectorWorker
    MiqEmsMetricsCollectorWorkerOpenstack
    MiqEmsMetricsCollectorWorkerOpenstackInfra
    MiqEmsMetricsProcessorWorker
    MiqEmsRefreshCoreWorker
    ManageIQ::Providers::Amazon::CloudManager::RefreshWorker
    MiqEmsRefreshWorkerForemanConfiguration
    MiqEmsRefreshWorkerForemanProvisioning
    MiqEmsRefreshWorkerKubernetes
    MiqEmsRefreshWorkerOpenshift
    MiqEmsRefreshWorkerMicrosoft
    ManageIQ::Providers::Redhat::InfraManager::RefreshWorker
    MiqEmsRefreshWorkerOpenstack
    MiqEmsRefreshWorkerOpenstackInfra
    ManageIQ::Providers::Vmware::InfraManager::RefreshWorker
    ManageIQ::Providers::Amazon::CloudManager::EventCatcher
    MiqEventCatcherKubernetes
    MiqEventCatcherOpenshift
    ManageIQ::Providers::Redhat::InfraManager::EventCatcher
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
    ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker
    ManageIQ::Providers::Redhat::InfraManager::MetricsCollectorWorker
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
    ManageIQ::Providers::Amazon::CloudManager::RefreshWorker
    MiqEmsRefreshWorkerForemanConfiguration
    MiqEmsRefreshWorkerForemanProvisioning
    MiqEmsRefreshWorkerKubernetes
    MiqEmsRefreshWorkerOpenshift
    MiqEmsRefreshWorkerMicrosoft
    ManageIQ::Providers::Redhat::InfraManager::RefreshWorker
    MiqEmsRefreshWorkerOpenstack
    MiqEmsRefreshWorkerOpenstackInfra
    ManageIQ::Providers::Vmware::InfraManager::RefreshWorker
    MiqScheduleWorker
    MiqPriorityWorker
    MiqWebServiceWorker
    MiqEmsRefreshCoreWorker
    MiqVimBrokerWorker
    ManageIQ::Providers::Vmware::InfraManager::EventCatcher
    ManageIQ::Providers::Redhat::InfraManager::EventCatcher
    MiqEventCatcherOpenstack
    MiqEventCatcherOpenstackInfra
    ManageIQ::Providers::Amazon::CloudManager::EventCatcher
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
