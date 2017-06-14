# TODO:  Consider putting this in a module namespace instead of poluting the
# global namespace

MIQ_WORKER_TYPES = {
  "ManageIQ::Providers::Azure::CloudManager::MetricsCollectorWorker" => [:manageiq_default],
  "ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker" => [:manageiq_default],
  "ManageIQ::Providers::Redhat::InfraManager::MetricsCollectorWorker" => [:manageiq_default],
  "ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCollectorWorker" => [:manageiq_default],
  "ManageIQ::Providers::Openshift::ContainerManager::MetricsCollectorWorker" => [:manageiq_default],
  "ManageIQ::Providers::Google::CloudManager::MetricsCollectorWorker" => [:manageiq_default],
  "ManageIQ::Providers::Vmware::InfraManager::MetricsCollectorWorker" => [:manageiq_default],
  "ManageIQ::Providers::Openstack::CloudManager::MetricsCollectorWorker" => [:manageiq_default],
  "ManageIQ::Providers::Openstack::NetworkManager::MetricsCollectorWorker" => [:manageiq_default],
  "ManageIQ::Providers::Openstack::InfraManager::MetricsCollectorWorker" => [:manageiq_default],
  "MiqEmsMetricsProcessorWorker" => [:manageiq_default],
  "MiqEmsRefreshCoreWorker" => [:manageiq_default],
  "ManageIQ::Providers::Azure::CloudManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Azure::NetworkManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Amazon::CloudManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Amazon::NetworkManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Amazon::StorageManager::Ebs::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Amazon::StorageManager::S3::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Google::CloudManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Google::NetworkManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::AnsibleTower::AutomationManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Foreman::ConfigurationManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Foreman::ProvisioningManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Hawkular::MiddlewareManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Hawkular::DatawarehouseManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Kubernetes::ContainerManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Microsoft::InfraManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Redhat::InfraManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Openstack::CloudManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Openstack::NetworkManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Openstack::InfraManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::StorageManager::CinderManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::StorageManager::SwiftManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Vmware::CloudManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Vmware::NetworkManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Vmware::InfraManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Nuage::NetworkManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Lenovo::PhysicalInfraManager::RefreshWorker" => [:manageiq_default],
  "ManageIQ::Providers::Amazon::CloudManager::EventCatcher" => [:manageiq_default],
  "ManageIQ::Providers::AnsibleTower::AutomationManager::EventCatcher" => [:manageiq_default],
  "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::EventCatcher" => [:manageiq_default],
  "ManageIQ::Providers::Azure::CloudManager::EventCatcher" => [:manageiq_default],
  "ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher" => [:manageiq_default],
  "ManageIQ::Providers::Hawkular::DatawarehouseManager::EventCatcher" => [:manageiq_default],
  "ManageIQ::Providers::Google::CloudManager::EventCatcher" => [:manageiq_default],
  "ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcher" => [:manageiq_default],
  "ManageIQ::Providers::Openshift::ContainerManager::EventCatcher" => [:manageiq_default],
  "ManageIQ::Providers::Redhat::InfraManager::EventCatcher" => [:manageiq_default],
  "ManageIQ::Providers::Openstack::CloudManager::EventCatcher" => [:manageiq_default],
  "ManageIQ::Providers::Openstack::NetworkManager::EventCatcher" => [:manageiq_default],
  "ManageIQ::Providers::Openstack::InfraManager::EventCatcher" => [:manageiq_default],
  "ManageIQ::Providers::StorageManager::CinderManager::EventCatcher" => [:manageiq_default],
  "ManageIQ::Providers::Vmware::InfraManager::EventCatcher" => [:manageiq_default],
  "ManageIQ::Providers::Vmware::CloudManager::EventCatcher" => [:manageiq_default],
  "ManageIQ::Providers::Lenovo::PhysicalInfraManager::EventCatcher" => [:manageiq_default],
  "EmbeddedAnsibleWorker" => [:manageiq_default],
  "MiqEventHandler" => [],
  "MiqGenericWorker" => [],
  "MiqPriorityWorker" => [],
  "MiqReportingWorker" => [],
  "MiqScheduleWorker" => [],
  "MiqSmartProxyWorker" => [:manageiq_default],
  "MiqWebsocketWorker" => %w(ui_dependencies web_server web_socket),
  "MiqUiWorker" => %w(web_server ui_dependencies),
  "MiqVimBrokerWorker" => [:manageiq_default],
  "MiqWebServiceWorker" => %w(web_server ui_dependencies),
  "MiqCockpitWsWorker" => [:manageiq_default]
}.freeze

MIQ_WORKER_TYPES_IN_KILL_ORDER = %w(
  MiqEmsMetricsProcessorWorker
  ManageIQ::Providers::Azure::CloudManager::MetricsCollectorWorker
  ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker
  ManageIQ::Providers::Redhat::InfraManager::MetricsCollectorWorker
  ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCollectorWorker
  ManageIQ::Providers::Openshift::ContainerManager::MetricsCollectorWorker
  ManageIQ::Providers::Google::CloudManager::MetricsCollectorWorker
  ManageIQ::Providers::Vmware::InfraManager::MetricsCollectorWorker
  ManageIQ::Providers::Openstack::CloudManager::MetricsCollectorWorker
  ManageIQ::Providers::Openstack::NetworkManager::MetricsCollectorWorker
  ManageIQ::Providers::Openstack::InfraManager::MetricsCollectorWorker
  EmbeddedAnsibleWorker
  MiqReportingWorker
  MiqSmartProxyWorker
  MiqGenericWorker
  MiqEventHandler
  ManageIQ::Providers::Azure::CloudManager::RefreshWorker
  ManageIQ::Providers::Azure::NetworkManager::RefreshWorker
  ManageIQ::Providers::Amazon::CloudManager::RefreshWorker
  ManageIQ::Providers::Amazon::NetworkManager::RefreshWorker
  ManageIQ::Providers::Amazon::StorageManager::Ebs::RefreshWorker
  ManageIQ::Providers::Amazon::StorageManager::S3::RefreshWorker
  ManageIQ::Providers::Google::CloudManager::RefreshWorker
  ManageIQ::Providers::Google::NetworkManager::RefreshWorker
  ManageIQ::Providers::AnsibleTower::AutomationManager::RefreshWorker
  ManageIQ::Providers::EmbeddedAnsible::AutomationManager::RefreshWorker
  ManageIQ::Providers::Foreman::ConfigurationManager::RefreshWorker
  ManageIQ::Providers::Foreman::ProvisioningManager::RefreshWorker
  ManageIQ::Providers::Hawkular::MiddlewareManager::RefreshWorker
  ManageIQ::Providers::Hawkular::DatawarehouseManager::RefreshWorker
  ManageIQ::Providers::Kubernetes::ContainerManager::RefreshWorker
  ManageIQ::Providers::Lenovo::PhysicalInfraManager::RefreshWorker
  ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker
  ManageIQ::Providers::Microsoft::InfraManager::RefreshWorker
  ManageIQ::Providers::Redhat::InfraManager::RefreshWorker
  ManageIQ::Providers::Openstack::CloudManager::RefreshWorker
  ManageIQ::Providers::Openstack::NetworkManager::RefreshWorker
  ManageIQ::Providers::Openstack::InfraManager::RefreshWorker
  ManageIQ::Providers::StorageManager::CinderManager::RefreshWorker
  ManageIQ::Providers::StorageManager::SwiftManager::RefreshWorker
  ManageIQ::Providers::Vmware::CloudManager::RefreshWorker
  ManageIQ::Providers::Vmware::NetworkManager::RefreshWorker
  ManageIQ::Providers::Vmware::InfraManager::RefreshWorker
  ManageIQ::Providers::Nuage::NetworkManager::RefreshWorker
  MiqScheduleWorker
  MiqPriorityWorker
  MiqWebServiceWorker
  MiqEmsRefreshCoreWorker
  MiqVimBrokerWorker
  ManageIQ::Providers::Vmware::CloudManager::EventCatcher
  ManageIQ::Providers::Vmware::InfraManager::EventCatcher
  ManageIQ::Providers::Redhat::InfraManager::EventCatcher
  ManageIQ::Providers::Openstack::CloudManager::EventCatcher
  ManageIQ::Providers::Openstack::NetworkManager::EventCatcher
  ManageIQ::Providers::Openstack::InfraManager::EventCatcher
  ManageIQ::Providers::StorageManager::CinderManager::EventCatcher
  ManageIQ::Providers::Amazon::CloudManager::EventCatcher
  ManageIQ::Providers::Azure::CloudManager::EventCatcher
  ManageIQ::Providers::AnsibleTower::AutomationManager::EventCatcher
  ManageIQ::Providers::EmbeddedAnsible::AutomationManager::EventCatcher
  ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher
  ManageIQ::Providers::Hawkular::DatawarehouseManager::EventCatcher
  ManageIQ::Providers::Google::CloudManager::EventCatcher
  ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcher
  ManageIQ::Providers::Openshift::ContainerManager::EventCatcher
  ManageIQ::Providers::Lenovo::PhysicalInfraManager::EventCatcher
  MiqUiWorker
  MiqWebsocketWorker
  MiqCockpitWsWorker
).freeze
