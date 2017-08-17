# TODO:  Consider putting this in a module namespace instead of poluting the
# global namespace

MIQ_WORKER_TYPES = {
  "ManageIQ::Providers::Amazon::CloudManager::EventCatcher"                   => [:amazon],
  "ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker"         => [:amazon],
  "ManageIQ::Providers::Amazon::CloudManager::RefreshWorker"                  => [:amazon],
  "ManageIQ::Providers::Amazon::NetworkManager::RefreshWorker"                => [:amazon],
  "ManageIQ::Providers::Amazon::StorageManager::Ebs::RefreshWorker"           => [:amazon],
  "ManageIQ::Providers::Amazon::StorageManager::S3::RefreshWorker"            => [:amazon],
  "ManageIQ::Providers::AnsibleTower::AutomationManager::EventCatcher"        => [:ansible],
  "ManageIQ::Providers::AnsibleTower::AutomationManager::RefreshWorker"       => [:ansible],
  "ManageIQ::Providers::Azure::CloudManager::EventCatcher"                    => [:azure],
  "ManageIQ::Providers::Azure::CloudManager::MetricsCollectorWorker"          => [:azure],
  "ManageIQ::Providers::Azure::CloudManager::RefreshWorker"                   => [:azure],
  "ManageIQ::Providers::Azure::NetworkManager::RefreshWorker"                 => [:azure],
  "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::EventCatcher"     => [:ansible],
  "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::RefreshWorker"    => [:ansible],
  "ManageIQ::Providers::Foreman::ConfigurationManager::RefreshWorker"         => [:foreman],
  "ManageIQ::Providers::Foreman::ProvisioningManager::RefreshWorker"          => [:foreman],
  "ManageIQ::Providers::Google::CloudManager::EventCatcher"                   => [:google],
  "ManageIQ::Providers::Google::CloudManager::MetricsCollectorWorker"         => [:google],
  "ManageIQ::Providers::Google::CloudManager::RefreshWorker"                  => [:google],
  "ManageIQ::Providers::Google::NetworkManager::RefreshWorker"                => [:google],
  "ManageIQ::Providers::Hawkular::DatawarehouseManager::EventCatcher"         => [:hawkular],
  "ManageIQ::Providers::Hawkular::DatawarehouseManager::RefreshWorker"        => [:hawkular],
  "ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher"            => [:hawkular],
  "ManageIQ::Providers::Hawkular::MiddlewareManager::RefreshWorker"           => [:hawkular],
  "ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcher"           => %i(kubernetes openshift),
  "ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCollectorWorker" => %i(kubernetes openshift),
  "ManageIQ::Providers::Kubernetes::ContainerManager::RefreshWorker"          => %i(kubernetes openshift),
  "ManageIQ::Providers::Lenovo::PhysicalInfraManager::EventCatcher"           => [:lenovo],
  "ManageIQ::Providers::Lenovo::PhysicalInfraManager::RefreshWorker"          => [:lenovo],
  "ManageIQ::Providers::Microsoft::InfraManager::RefreshWorker"               => [:manageiq_default],
  "ManageIQ::Providers::Nuage::NetworkManager::RefreshWorker"                 => [:nuage],
  "ManageIQ::Providers::Openshift::ContainerManager::EventCatcher"            => %i(kubernetes openshift),
  "ManageIQ::Providers::Openshift::ContainerManager::MetricsCollectorWorker"  => %i(kubernetes openshift),
  "ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker"           => %i(kubernetes openshift),
  "ManageIQ::Providers::Openstack::CloudManager::EventCatcher"                => [:openstack],
  "ManageIQ::Providers::Openstack::CloudManager::MetricsCollectorWorker"      => [:openstack],
  "ManageIQ::Providers::Openstack::CloudManager::RefreshWorker"               => [:openstack],
  "ManageIQ::Providers::Openstack::InfraManager::EventCatcher"                => [:openstack],
  "ManageIQ::Providers::Openstack::InfraManager::MetricsCollectorWorker"      => [:openstack],
  "ManageIQ::Providers::Openstack::InfraManager::RefreshWorker"               => [:openstack],
  "ManageIQ::Providers::Openstack::NetworkManager::EventCatcher"              => [:openstack],
  "ManageIQ::Providers::Openstack::NetworkManager::MetricsCollectorWorker"    => [:openstack],
  "ManageIQ::Providers::Openstack::NetworkManager::RefreshWorker"             => [:openstack],
  "ManageIQ::Providers::Redhat::InfraManager::EventCatcher"                   => [:ovirt],
  "ManageIQ::Providers::Redhat::InfraManager::MetricsCollectorWorker"         => [:ovirt],
  "ManageIQ::Providers::Redhat::InfraManager::RefreshWorker"                  => [:ovirt],
  "ManageIQ::Providers::StorageManager::CinderManager::EventCatcher"          => [:openstack],
  "ManageIQ::Providers::StorageManager::CinderManager::RefreshWorker"         => [:openstack],
  "ManageIQ::Providers::StorageManager::SwiftManager::RefreshWorker"          => [:openstack],
  "ManageIQ::Providers::Vmware::CloudManager::EventCatcher"                   => [:vmware],
  "ManageIQ::Providers::Vmware::CloudManager::RefreshWorker"                  => [:vmware],
  "ManageIQ::Providers::Vmware::InfraManager::EventCatcher"                   => [:vmware],
  "ManageIQ::Providers::Vmware::InfraManager::MetricsCollectorWorker"         => [:vmware],
  "ManageIQ::Providers::Vmware::InfraManager::RefreshWorker"                  => [:vmware],
  "ManageIQ::Providers::Vmware::NetworkManager::RefreshWorker"                => [:vmware],
  "EmbeddedAnsibleWorker"                                                     => [],
  "MiqCockpitWsWorker"                                                        => [:cockpit],
  "MiqEmsMetricsProcessorWorker"                                              => [],
  "MiqEmsRefreshCoreWorker"                                                   => [],
  "MiqEventHandler"                                                           => [],
  "MiqGenericWorker"                                                          => [:manageiq_default],
  "MiqPriorityWorker"                                                         => [],
  "MiqReportingWorker"                                                        => [],
  "MiqScheduleWorker"                                                         => [:scheduler],
  "MiqSmartProxyWorker"                                                       => [:smartstate],
  "MiqUiWorker"                                                               => [:manageiq_default],
  "MiqVimBrokerWorker"                                                        => [:manageiq_default],
  "MiqWebServiceWorker"                                                       => %i(automate rest_api ui_dependencies web_server),
  "MiqWebsocketWorker"                                                        => %i(ui_dependencies web_server web_socket)
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
