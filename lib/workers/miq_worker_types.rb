# TODO:  Consider putting this in a module namespace instead of poluting the
# global namespace

MIQ_WORKER_TYPES = {
<<<<<<< HEAD
  "ManageIQ::Providers::Amazon::CloudManager::EventCatcher"                   => %i(manageiq_default),
  "ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker"         => %i(manageiq_default),
  "ManageIQ::Providers::Amazon::CloudManager::RefreshWorker"                  => %i(manageiq_default),
  "ManageIQ::Providers::Amazon::NetworkManager::RefreshWorker"                => %i(manageiq_default),
  "ManageIQ::Providers::Amazon::StorageManager::Ebs::RefreshWorker"           => %i(manageiq_default),
  "ManageIQ::Providers::Amazon::StorageManager::S3::RefreshWorker"            => %i(manageiq_default),
  "ManageIQ::Providers::AnsibleTower::AutomationManager::EventCatcher"        => %i(manageiq_default),
  "ManageIQ::Providers::AnsibleTower::AutomationManager::RefreshWorker"       => %i(manageiq_default),
  "ManageIQ::Providers::Azure::CloudManager::EventCatcher"                    => %i(manageiq_default),
  "ManageIQ::Providers::Azure::CloudManager::MetricsCollectorWorker"          => %i(manageiq_default),
  "ManageIQ::Providers::Azure::CloudManager::RefreshWorker"                   => %i(manageiq_default),
  "ManageIQ::Providers::Azure::NetworkManager::RefreshWorker"                 => %i(manageiq_default),
  "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::EventCatcher"     => %i(manageiq_default),
  "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::RefreshWorker"    => %i(manageiq_default),
  "ManageIQ::Providers::Foreman::ConfigurationManager::RefreshWorker"         => %i(manageiq_default),
  "ManageIQ::Providers::Foreman::ProvisioningManager::RefreshWorker"          => %i(manageiq_default),
  "ManageIQ::Providers::Google::CloudManager::EventCatcher"                   => %i(manageiq_default),
  "ManageIQ::Providers::Google::CloudManager::MetricsCollectorWorker"         => %i(manageiq_default),
  "ManageIQ::Providers::Google::CloudManager::RefreshWorker"                  => %i(manageiq_default),
  "ManageIQ::Providers::Google::NetworkManager::RefreshWorker"                => %i(manageiq_default),
  "ManageIQ::Providers::Hawkular::DatawarehouseManager::EventCatcher"         => %i(manageiq_default),
  "ManageIQ::Providers::Hawkular::DatawarehouseManager::RefreshWorker"        => %i(manageiq_default),
  "ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher"            => %i(manageiq_default),
  "ManageIQ::Providers::Hawkular::MiddlewareManager::RefreshWorker"           => %i(manageiq_default),
  "ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcher"           => %i(manageiq_default),
  "ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCollectorWorker" => %i(manageiq_default),
  "ManageIQ::Providers::Kubernetes::ContainerManager::RefreshWorker"          => %i(manageiq_default),
  "ManageIQ::Providers::Lenovo::PhysicalInfraManager::EventCatcher"           => %i(manageiq_default),
  "ManageIQ::Providers::Lenovo::PhysicalInfraManager::RefreshWorker"          => %i(manageiq_default),
  "ManageIQ::Providers::Microsoft::InfraManager::RefreshWorker"               => %i(manageiq_default),
  "ManageIQ::Providers::Nuage::NetworkManager::RefreshWorker"                 => %i(manageiq_default),
  "ManageIQ::Providers::Openshift::ContainerManager::EventCatcher"            => %i(manageiq_default),
  "ManageIQ::Providers::Openshift::ContainerManager::MetricsCollectorWorker"  => %i(manageiq_default),
  "ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker"           => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::CloudManager::EventCatcher"                => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::CloudManager::MetricsCollectorWorker"      => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::CloudManager::RefreshWorker"               => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::InfraManager::EventCatcher"                => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::InfraManager::MetricsCollectorWorker"      => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::InfraManager::RefreshWorker"               => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::NetworkManager::EventCatcher"              => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::NetworkManager::MetricsCollectorWorker"    => %i(manageiq_default),
  "ManageIQ::Providers::Openstack::NetworkManager::RefreshWorker"             => %i(manageiq_default),
  "ManageIQ::Providers::Redhat::InfraManager::EventCatcher"                   => %i(manageiq_default),
  "ManageIQ::Providers::Redhat::InfraManager::MetricsCollectorWorker"         => %i(manageiq_default),
  "ManageIQ::Providers::Redhat::InfraManager::RefreshWorker"                  => %i(manageiq_default),
  "ManageIQ::Providers::StorageManager::CinderManager::RefreshWorker"         => %i(manageiq_default),
  "ManageIQ::Providers::StorageManager::SwiftManager::RefreshWorker"          => %i(manageiq_default),
  "ManageIQ::Providers::Vmware::CloudManager::EventCatcher"                   => %i(manageiq_default),
  "ManageIQ::Providers::Vmware::CloudManager::RefreshWorker"                  => %i(manageiq_default),
  "ManageIQ::Providers::Vmware::InfraManager::EventCatcher"                   => %i(manageiq_default),
  "ManageIQ::Providers::Vmware::InfraManager::MetricsCollectorWorker"         => %i(manageiq_default),
  "ManageIQ::Providers::Vmware::InfraManager::RefreshWorker"                  => %i(manageiq_default),
  "ManageIQ::Providers::Vmware::NetworkManager::RefreshWorker"                => %i(manageiq_default),
  "EmbeddedAnsibleWorker"                                                     => %i(manageiq_default),
  "MiqCockpitWsWorker"                                                        => %i(manageiq_default),
  "MiqEmsMetricsProcessorWorker"                                              => %i(manageiq_default),
  "MiqEmsRefreshCoreWorker"                                                   => %i(manageiq_default),
  "MiqEventHandler"                                                           => %i(manageiq_default),
  "MiqGenericWorker"                                                          => %i(manageiq_default),
  "MiqPriorityWorker"                                                         => %i(manageiq_default),
  "MiqReportingWorker"                                                        => %i(manageiq_default),
  "MiqScheduleWorker"                                                         => %i(manageiq_default),
  "MiqSmartProxyWorker"                                                       => %i(manageiq_default),
  "MiqUiWorker"                                                               => %i(manageiq_default ui_dependencies),
  "MiqVimBrokerWorker"                                                        => %i(manageiq_default),
  "MiqWebServiceWorker"                                                       => %i(manageiq_default),
  "MiqWebsocketWorker"                                                        => %i(manageiq_default),
=======
  "ManageIQ::Providers::Amazon::CloudManager::EventCatcher"                   => [:amazon],
  "ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker"         => [:amazon],
  "ManageIQ::Providers::Amazon::CloudManager::RefreshWorker"                  => [:amazon],
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
  "MiqGenericWorker"                                                          => [],
  "MiqPriorityWorker"                                                         => [],
  "MiqReportingWorker"                                                        => [],
  "MiqScheduleWorker"                                                         => [:scheduler],
  "MiqSmartProxyWorker"                                                       => [:smartstate],
  "MiqUiWorker"                                                               => %i(ui_dependencies web_server),
  "MiqVimBrokerWorker"                                                        => [:manageiq_default],
  "MiqWebServiceWorker"                                                       => %i(rest_api ui_dependencies web_server),
  "MiqWebsocketWorker"                                                        => %i(ui_dependencies web_server web_socket)
>>>>>>> Only start Amazon Cloud Refresher
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
