# TODO:  Consider putting this in a module namespace instead of poluting the
# global namespace

MIQ_WORKER_TYPES = {
  "ManageIQ::Providers::Amazon::AgentCoordinatorWorker"                         => %i(manageiq_default),
  "ManageIQ::Providers::Amazon::CloudManager::EventCatcher"                     => %i(manageiq_default),
  "ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker"           => %i(manageiq_default),
  "ManageIQ::Providers::Amazon::CloudManager::RefreshWorker"                    => %i(manageiq_default),
  "ManageIQ::Providers::Amazon::StorageManager::S3::RefreshWorker"              => %i(manageiq_default),
  "ManageIQ::Providers::AnsibleTower::AutomationManager::EventCatcher"          => %i(manageiq_default),
  "ManageIQ::Providers::AnsibleTower::AutomationManager::RefreshWorker"         => %i(manageiq_default),
  "ManageIQ::Providers::Azure::CloudManager::EventCatcher"                      => %i(manageiq_default),
  "ManageIQ::Providers::Azure::CloudManager::MetricsCollectorWorker"            => %i(manageiq_default),
  "ManageIQ::Providers::Azure::CloudManager::RefreshWorker"                     => %i(manageiq_default),
  "ManageIQ::Providers::AzureStack::CloudManager::EventCatcher"                 => %i[manageiq_default],
  "ManageIQ::Providers::AzureStack::CloudManager::RefreshWorker"                => %i[manageiq_default],
  "ManageIQ::Providers::AzureStack::NetworkManager::RefreshWorker"              => %i[manageiq_default],
  "ManageIQ::Providers::Foreman::ConfigurationManager::RefreshWorker"           => %i(manageiq_default),
  "ManageIQ::Providers::Foreman::ProvisioningManager::RefreshWorker"            => %i(manageiq_default),
  "ManageIQ::Providers::Google::CloudManager::EventCatcher"                     => %i(manageiq_default),
  "ManageIQ::Providers::Google::CloudManager::MetricsCollectorWorker"           => %i(manageiq_default),
  "ManageIQ::Providers::Google::CloudManager::RefreshWorker"                    => %i(manageiq_default),
  "ManageIQ::Providers::Google::NetworkManager::RefreshWorker"                  => %i(manageiq_default),
  "ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcher"             => %i(manageiq_default),
  "ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCollectorWorker"   => %i(manageiq_default),
  "ManageIQ::Providers::Kubernetes::ContainerManager::InventoryCollectorWorker" => %i(manageiq_default),
  "ManageIQ::Providers::Kubernetes::ContainerManager::RefreshWorker"            => %i(manageiq_default),
  "ManageIQ::Providers::Kubernetes::MonitoringManager::EventCatcher"            => %i(manageiq_default),
  "ManageIQ::Providers::Kubevirt::InfraManager::RefreshWorker"                  => %i(manageiq_default),
  "ManageIQ::Providers::Lenovo::PhysicalInfraManager::EventCatcher"             => %i(manageiq_default),
  "ManageIQ::Providers::Lenovo::PhysicalInfraManager::RefreshWorker"            => %i(manageiq_default),
  "ManageIQ::Providers::Microsoft::InfraManager::RefreshWorker"                 => %i(manageiq_default),
  "ManageIQ::Providers::Nuage::NetworkManager::RefreshWorker"                   => %i(manageiq_default),
  "ManageIQ::Providers::Nuage::NetworkManager::EventCatcher"                    => %i(manageiq_default),
  "ManageIQ::Providers::Openshift::ContainerManager::EventCatcher"              => %i(manageiq_default),
  "ManageIQ::Providers::Openshift::ContainerManager::MetricsCollectorWorker"    => %i(manageiq_default),
  "ManageIQ::Providers::Openshift::ContainerManager::InventoryCollectorWorker"  => %i(manageiq_default),
  "ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker"             => %i(manageiq_default),
  "ManageIQ::Providers::Openshift::MonitoringManager::EventCatcher"             => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::CloudManager::EventCatcher"                  => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::CloudManager::MetricsCollectorWorker"        => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::CloudManager::RefreshWorker"                 => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::InfraManager::EventCatcher"                  => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::InfraManager::MetricsCollectorWorker"        => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::InfraManager::RefreshWorker"                 => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::NetworkManager::EventCatcher"                => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::NetworkManager::MetricsCollectorWorker"      => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::StorageManager::CinderManager::EventCatcher" => %i(manageiq_default),
  "ManageIQ::Providers::Redfish::PhysicalInfraManager::EventCatcher"            => %i(manageiq_default),
  "ManageIQ::Providers::Redfish::PhysicalInfraManager::RefreshWorker"           => %i(manageiq_default),
  "ManageIQ::Providers::Redhat::InfraManager::EventCatcher"                     => %i(manageiq_default),
  "ManageIQ::Providers::Redhat::InfraManager::MetricsCollectorWorker"           => %i(manageiq_default),
  "ManageIQ::Providers::Redhat::InfraManager::RefreshWorker"                    => %i(manageiq_default),
  "ManageIQ::Providers::Redhat::NetworkManager::EventCatcher"                   => %i(manageiq_default),
  "ManageIQ::Providers::Redhat::NetworkManager::MetricsCollectorWorker"         => %i(manageiq_default),
  "ManageIQ::Providers::Redhat::NetworkManager::RefreshWorker"                  => %i(manageiq_default),
  "ManageIQ::Providers::Vmware::CloudManager::EventCatcher"                     => %i(manageiq_default),
  "ManageIQ::Providers::Vmware::CloudManager::RefreshWorker"                    => %i(manageiq_default),
  "ManageIQ::Providers::Vmware::InfraManager::EventCatcher"                     => %i(manageiq_default),
  "ManageIQ::Providers::Vmware::InfraManager::MetricsCollectorWorker"           => %i(manageiq_default),
  "ManageIQ::Providers::Vmware::InfraManager::RefreshWorker"                    => %i(manageiq_default),
  "ManageIQ::Providers::Vmware::NetworkManager::RefreshWorker"                  => %i(manageiq_default),
  "MiqCockpitWsWorker"                                                          => %i(manageiq_default),
  "MiqEmsMetricsProcessorWorker"                                                => %i(manageiq_default),
  "MiqEmsRefreshCoreWorker"                                                     => %i(manageiq_default),
  "MiqEventHandler"                                                             => %i(manageiq_default),
  "MiqGenericWorker"                                                            => %i(manageiq_default),
  "MiqPriorityWorker"                                                           => %i(manageiq_default),
  "MiqReportingWorker"                                                          => %i(manageiq_default),
  "MiqScheduleWorker"                                                           => %i(manageiq_default),
  "MiqSmartProxyWorker"                                                         => %i(manageiq_default),
  "MiqUiWorker"                                                                 => %i(manageiq_default ui_dependencies),
  "MiqVimBrokerWorker"                                                          => %i(manageiq_default),
  "MiqWebServiceWorker"                                                         => %i(manageiq_default),
  "MiqRemoteConsoleWorker"                                                      => %i(manageiq_default),
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
  ManageIQ::Providers::Redhat::NetworkManager::MetricsCollectorWorker
  ManageIQ::Providers::Openstack::InfraManager::MetricsCollectorWorker
  MiqReportingWorker
  MiqSmartProxyWorker
  MiqGenericWorker
  MiqEventHandler
  ManageIQ::Providers::Azure::CloudManager::RefreshWorker
  ManageIQ::Providers::Azure::NetworkManager::RefreshWorker
  ManageIQ::Providers::AzureStack::CloudManager::RefreshWorker
  ManageIQ::Providers::AzureStack::NetworkManager::RefreshWorker
  ManageIQ::Providers::Amazon::CloudManager::RefreshWorker
  ManageIQ::Providers::Amazon::NetworkManager::RefreshWorker
  ManageIQ::Providers::Amazon::StorageManager::Ebs::RefreshWorker
  ManageIQ::Providers::Amazon::StorageManager::S3::RefreshWorker
  ManageIQ::Providers::Amazon::AgentCoordinatorWorker
  ManageIQ::Providers::Google::CloudManager::RefreshWorker
  ManageIQ::Providers::Google::NetworkManager::RefreshWorker
  ManageIQ::Providers::AnsibleTower::AutomationManager::RefreshWorker
  ManageIQ::Providers::Foreman::ConfigurationManager::RefreshWorker
  ManageIQ::Providers::Foreman::ProvisioningManager::RefreshWorker
  ManageIQ::Providers::Kubernetes::ContainerManager::InventoryCollectorWorker
  ManageIQ::Providers::Kubernetes::ContainerManager::RefreshWorker
  ManageIQ::Providers::Lenovo::PhysicalInfraManager::RefreshWorker
  ManageIQ::Providers::Openshift::ContainerManager::InventoryCollectorWorker
  ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker
  ManageIQ::Providers::Microsoft::InfraManager::RefreshWorker
  ManageIQ::Providers::Redfish::PhysicalInfraManager::RefreshWorker
  ManageIQ::Providers::Redhat::InfraManager::RefreshWorker
  ManageIQ::Providers::Openstack::CloudManager::RefreshWorker
  ManageIQ::Providers::Openstack::NetworkManager::RefreshWorker
  ManageIQ::Providers::Redhat::NetworkManager::RefreshWorker
  ManageIQ::Providers::Openstack::InfraManager::RefreshWorker
  ManageIQ::Providers::StorageManager::CinderManager::RefreshWorker
  ManageIQ::Providers::StorageManager::SwiftManager::RefreshWorker
  ManageIQ::Providers::Vmware::CloudManager::RefreshWorker
  ManageIQ::Providers::Vmware::NetworkManager::RefreshWorker
  ManageIQ::Providers::Vmware::InfraManager::RefreshWorker
  ManageIQ::Providers::Nuage::NetworkManager::RefreshWorker
  ManageIQ::Providers::Nuage::NetworkManager::EventCatcher
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
  ManageIQ::Providers::Openstack::StorageManager::CinderManager::EventCatcher
  ManageIQ::Providers::Redfish::PhysicalInfraManager::EventCatcher
  ManageIQ::Providers::Redhat::NetworkManager::EventCatcher
  ManageIQ::Providers::Openstack::InfraManager::EventCatcher
  ManageIQ::Providers::Amazon::CloudManager::EventCatcher
  ManageIQ::Providers::Azure::CloudManager::EventCatcher
  ManageIQ::Providers::AzureStack::CloudManager::EventCatcher
  ManageIQ::Providers::AnsibleTower::AutomationManager::EventCatcher
  ManageIQ::Providers::Google::CloudManager::EventCatcher
  ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcher
  ManageIQ::Providers::Kubernetes::MonitoringManager::EventCatcher
  ManageIQ::Providers::Kubevirt::InfraManager::RefreshWorker
  ManageIQ::Providers::Openshift::ContainerManager::EventCatcher
  ManageIQ::Providers::Openshift::MonitoringManager::EventCatcher
  ManageIQ::Providers::Lenovo::PhysicalInfraManager::EventCatcher
  MiqUiWorker
  MiqRemoteConsoleWorker
  MiqCockpitWsWorker
).freeze
