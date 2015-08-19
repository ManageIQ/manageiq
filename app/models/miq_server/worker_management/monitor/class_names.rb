module MiqServer::WorkerManagement::Monitor::ClassNames
  extend ActiveSupport::Concern

  MONITOR_CLASS_NAMES = %w{
    ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker
    ManageIQ::Providers::Redhat::InfraManager::MetricsCollectorWorker
    ManageIQ::Providers::Vmware::InfraManager::MetricsCollectorWorker
    ManageIQ::Providers::Openstack::CloudManager::MetricsCollectorWorker
    ManageIQ::Providers::Openstack::InfraManager::MetricsCollectorWorker
    MiqEmsMetricsProcessorWorker
    MiqEmsRefreshCoreWorker
    MiqEmsRefreshWorkerAzure
    ManageIQ::Providers::Amazon::CloudManager::RefreshWorker
    ManageIQ::Providers::Foreman::ConfigurationManager::RefreshWorker
    ManageIQ::Providers::Foreman::ProvisioningManager::RefreshWorker
    ManageIQ::Providers::Kubernetes::ContainerManager::RefreshWorker
    ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker
    ManageIQ::Providers::Microsoft::InfraManager::RefreshWorker
    ManageIQ::Providers::Redhat::InfraManager::RefreshWorker
    ManageIQ::Providers::Openstack::CloudManager::RefreshWorker
    ManageIQ::Providers::Openstack::InfraManager::RefreshWorker
    ManageIQ::Providers::Vmware::InfraManager::RefreshWorker
    ManageIQ::Providers::Amazon::CloudManager::EventCatcher
    ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcher
    ManageIQ::Providers::Openshift::ContainerManager::EventCatcher
    ManageIQ::Providers::Redhat::InfraManager::EventCatcher
    ManageIQ::Providers::Openstack::CloudManager::EventCatcher
    ManageIQ::Providers::Openstack::InfraManager::EventCatcher
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
    ManageIQ::Providers::Openstack::CloudManager::MetricsCollectorWorker
    ManageIQ::Providers::Openstack::InfraManager::MetricsCollectorWorker
    MiqReportingWorker
    MiqSmartProxyWorker
    MiqReplicationWorker
    MiqGenericWorker
    MiqEventHandler
    MiqSmisRefreshWorker
    MiqNetappRefreshWorker
    MiqVmdbStorageBridgeWorker
    MiqStorageMetricsCollectorWorker
    MiqEmsRefreshWorkerAzure
    ManageIQ::Providers::Amazon::CloudManager::RefreshWorker
    ManageIQ::Providers::Foreman::ConfigurationManager::RefreshWorker
    ManageIQ::Providers::Foreman::ProvisioningManager::RefreshWorker
    ManageIQ::Providers::Kubernetes::ContainerManager::RefreshWorker
    ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker
    ManageIQ::Providers::Microsoft::InfraManager::RefreshWorker
    ManageIQ::Providers::Redhat::InfraManager::RefreshWorker
    ManageIQ::Providers::Openstack::CloudManager::RefreshWorker
    ManageIQ::Providers::Openstack::InfraManager::RefreshWorker
    ManageIQ::Providers::Vmware::InfraManager::RefreshWorker
    MiqScheduleWorker
    MiqPriorityWorker
    MiqWebServiceWorker
    MiqEmsRefreshCoreWorker
    MiqVimBrokerWorker
    ManageIQ::Providers::Vmware::InfraManager::EventCatcher
    ManageIQ::Providers::Redhat::InfraManager::EventCatcher
    ManageIQ::Providers::Openstack::CloudManager::EventCatcher
    ManageIQ::Providers::Openstack::InfraManager::EventCatcher
    ManageIQ::Providers::Amazon::CloudManager::EventCatcher
    ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcher
    ManageIQ::Providers::Openshift::ContainerManager::EventCatcher
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
