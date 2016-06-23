class NamespaceEmsRedhat < ActiveRecord::Migration
  include MigrationHelper

  NAME_MAP = Hash[*%w(
    EmsRedhat                                  ManageIQ::Providers::Redhat::CloudManager
    AvailabilityZoneRedhat                     ManageIQ::Providers::Redhat::CloudManager::AvailabilityZone
    CloudVolumeRedhat                          ManageIQ::Providers::Redhat::CloudManager::CloudVolume
    CloudVolumeSnapshotRedhat                  ManageIQ::Providers::Redhat::CloudManager::CloudVolumeSnapshot
    MiqEventCatcherRedhat                      ManageIQ::Providers::Redhat::CloudManager::EventCatcher
    EventCatcherRedhat                         ManageIQ::Providers::Redhat::CloudManager::EventCatcher::Runner
    FlavorRedhat                               ManageIQ::Providers::Redhat::CloudManager::Flavor
    FloatingIpRedhat                           ManageIQ::Providers::Redhat::CloudManager::FloatingIp
    MiqEmsMetricsCollectorWorkerRedhat         ManageIQ::Providers::Redhat::CloudManager::MetricsCollectorWorker
    EmsMetricsCollectorWorkerRedhat            ManageIQ::Providers::Redhat::CloudManager::MetricsCollectorWorker::Runner
    OrchestrationStackRedhat                   ManageIQ::Providers::Redhat::CloudManager::OrchestrationStack
    MiqEmsRefreshWorkerRedhat                  ManageIQ::Providers::Redhat::CloudManager::RefreshWorker
    EmsRefreshWorkerRedhat                     ManageIQ::Providers::Redhat::CloudManager::RefreshWorker::Runner
    SecurityGroupRedhat                        ManageIQ::Providers::Redhat::CloudManager::SecurityGroup
    TemplateRedhat                             ManageIQ::Providers::Redhat::CloudManager::Template
    VmRedhat                                   ManageIQ::Providers::Redhat::CloudManager::Vm
  )]

  def change
    rename_class_references(NAME_MAP)
  end
end
