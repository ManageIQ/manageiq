# TODO:  Consider putting this in a module namespace instead of poluting the
# global namespace

MIQ_DEFAULT_BUNDLER_GROUPS = %w(
  amazon
  ansible
  azure
  foreman
  google
  hawkular
  kubernetes
  lenovo
  openshift
  openstack
  ovirt
  scvmm
  vmware
  replication
  rest_api
  ui_dependencies
  web_server
  web_socket
)

MIQ_WORKER_TYPES = {
  "ManageIQ::Providers::Azure::CloudManager::MetricsCollectorWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Redhat::InfraManager::MetricsCollectorWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCollectorWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Openshift::ContainerManager::MetricsCollectorWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Google::CloudManager::MetricsCollectorWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Vmware::InfraManager::MetricsCollectorWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Openstack::CloudManager::MetricsCollectorWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Openstack::NetworkManager::MetricsCollectorWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Openstack::InfraManager::MetricsCollectorWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "MiqEmsMetricsProcessorWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "MiqEmsRefreshCoreWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Azure::CloudManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Azure::NetworkManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Amazon::CloudManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Amazon::NetworkManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Amazon::StorageManager::Ebs::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Amazon::StorageManager::S3::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Google::CloudManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Google::NetworkManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::AnsibleTower::AutomationManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Foreman::ConfigurationManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Foreman::ProvisioningManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Hawkular::MiddlewareManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Hawkular::DatawarehouseManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Kubernetes::ContainerManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Microsoft::InfraManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Redhat::InfraManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Openstack::CloudManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Openstack::NetworkManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Openstack::InfraManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::StorageManager::CinderManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::StorageManager::SwiftManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Vmware::CloudManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Vmware::NetworkManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Vmware::InfraManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Nuage::NetworkManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Lenovo::PhysicalInfraManager::RefreshWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Amazon::CloudManager::EventCatcher" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::AnsibleTower::AutomationManager::EventCatcher" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::EventCatcher" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Azure::CloudManager::EventCatcher" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Hawkular::DatawarehouseManager::EventCatcher" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Google::CloudManager::EventCatcher" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcher" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Openshift::ContainerManager::EventCatcher" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Redhat::InfraManager::EventCatcher" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Openstack::CloudManager::EventCatcher" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Openstack::NetworkManager::EventCatcher" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Openstack::InfraManager::EventCatcher" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::StorageManager::CinderManager::EventCatcher" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Vmware::InfraManager::EventCatcher" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Vmware::CloudManager::EventCatcher" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "ManageIQ::Providers::Lenovo::PhysicalInfraManager::EventCatcher" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "EmbeddedAnsibleWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "MiqEventHandler" => [],
  "MiqGenericWorker" => [],
  "MiqPriorityWorker" => [],
  "MiqReportingWorker" => [],
  "MiqScheduleWorker" => [],
  "MiqSmartProxyWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "MiqWebsocketWorker" => %w(ui_dependencies web_server web_socket),
  "MiqUiWorker" => %w(web_server ui_dependencies),
  "MiqVimBrokerWorker" => MIQ_DEFAULT_BUNDLER_GROUPS,
  "MiqWebServiceWorker" => %w(web_server ui_dependencies),
  "MiqCockpitWsWorker" => MIQ_DEFAULT_BUNDLER_GROUPS
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
