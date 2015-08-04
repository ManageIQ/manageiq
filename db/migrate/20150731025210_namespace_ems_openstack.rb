class NamespaceEmsOpenstack < ActiveRecord::Migration
  include MigrationHelper

  NAME_MAP = Hash[*%w(
    ProviderOpenstack                       ManageIQ::Providers::Openstack::Provider

    EmsOpenstack                            ManageIQ::Providers::Openstack::CloudManager
    AuthKeyPairOpenstack                    ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair
    AvailabilityZoneOpenstack               ManageIQ::Providers::Openstack::CloudManager::AvailabilityZone
    CloudResourceQuotaOpenstack             ManageIQ::Providers::Openstack::CloudManager::CloudResourceQuota
    CloudTenantOpenstack                    ManageIQ::Providers::Openstack::CloudManager::CloudTenant
    CloudVolumeOpenstack                    ManageIQ::Providers::Openstack::CloudManager::CloudVolume
    CloudVolumeSnapshotOpenstack            ManageIQ::Providers::Openstack::CloudManager::CloudVolumeSnapshot
    MiqEventCatcherOpenstack                ManageIQ::Providers::Openstack::CloudManager::EventCatcher
    EventCatcherOpenstack                   ManageIQ::Providers::Openstack::CloudManager::EventCatcher::Runner
    FlavorOpenstack                         ManageIQ::Providers::Openstack::CloudManager::Flavor
    FloatingIpOpenstack                     ManageIQ::Providers::Openstack::CloudManager::FloatingIp
    MiqEmsMetricsCollectorWorkerOpenstack   ManageIQ::Providers::Openstack::CloudManager::MetricsCollectorWorker
    EmsMetricsCollectorWorkerOpenstack      ManageIQ::Providers::Openstack::CloudManager::MetricsCollectorWorker::Runner
    OrchestrationStackOpenstack             ManageIQ::Providers::Openstack::CloudManager::OrchestrationStack
    MiqEmsRefreshWorkerOpenstack            ManageIQ::Providers::Openstack::CloudManager::RefreshWorker
    EmsRefreshWorkerOpenstack               ManageIQ::Providers::Openstack::CloudManager::RefreshWorker::Runner
    SecurityGroupOpenstack                  ManageIQ::Providers::Openstack::CloudManager::SecurityGroup
    TemplateOpenstack                       ManageIQ::Providers::Openstack::CloudManager::Template
    VmOpenstack                             ManageIQ::Providers::Openstack::CloudManager::Vm

    ServiceOrchestration::OptionConverterOpenstack
                                       ManageIQ::Providers::Openstack::CloudManager::OrchestrationServiceOptionConverter


    EmsOpenstackInfra                       ManageIQ::Providers::Openstack::InfraManager
    AuthKeyPairOpenstackInfra               ManageIQ::Providers::Openstack::InfraManager::AuthKeyPair
    EmsClusterOpenstackInfra                ManageIQ::Providers::Openstack::InfraManager::EmsCluster
    MiqEventCatcherOpenstackInfra           ManageIQ::Providers::Openstack::InfraManager::EventCatcher
    EventCatcherOpenstackInfra              ManageIQ::Providers::Openstack::InfraManager::EventCatcher::Runner
    HostOpenstackInfra                      ManageIQ::Providers::Openstack::InfraManager::Host
    HostServiceGroupOpenstack               ManageIQ::Providers::Openstack::InfraManager::HostServiceGroup
    MiqEmsMetricsCollectorWorkerOpenstackInfra      ManageIQ::Providers::Openstack::InfraManager::MetricsCollectorWorker
    EmsMetricsCollectorWorkerOpenstackInfra ManageIQ::Providers::Openstack::InfraManager::MetricsCollectorWorker::Runner
    OrchestrationStackOpenstackInfra        ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack
    MiqEmsRefreshWorkerOpenstackInfra       ManageIQ::Providers::Openstack::InfraManager::RefreshWorker
    EmsRefreshWorkerOpenstackInfra          ManageIQ::Providers::Openstack::InfraManager::RefreshWorker::Runner
  )]

  def change
    rename_class_references(NAME_MAP)
  end
end
