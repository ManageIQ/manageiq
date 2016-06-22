class NamespaceEmsAmazon < ActiveRecord::Migration
  include MigrationHelper

  NAME_MAP = Hash[*%w(
    AuthKeyPairCloud                           ManageIQ::Providers::CloudManager::AuthKeyPair

    EmsAmazon                                  ManageIQ::Providers::Amazon::CloudManager
    AvailabilityZoneAmazon                     ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone
    CloudVolumeAmazon                          ManageIQ::Providers::Amazon::CloudManager::CloudVolume
    CloudVolumeSnapshotAmazon                  ManageIQ::Providers::Amazon::CloudManager::CloudVolumeSnapshot
    MiqEventCatcherAmazon                      ManageIQ::Providers::Amazon::CloudManager::EventCatcher
    EventCatcherAmazon                         ManageIQ::Providers::Amazon::CloudManager::EventCatcher::Runner
    FlavorAmazon                               ManageIQ::Providers::Amazon::CloudManager::Flavor
    FloatingIpAmazon                           ManageIQ::Providers::Amazon::CloudManager::FloatingIp
    MiqEmsMetricsCollectorWorkerAmazon         ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker
    EmsMetricsCollectorWorkerAmazon            ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker::Runner
    OrchestrationStackAmazon                   ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack
    MiqEmsRefreshWorkerAmazon                  ManageIQ::Providers::Amazon::CloudManager::RefreshWorker
    EmsRefreshWorkerAmazon                     ManageIQ::Providers::Amazon::CloudManager::RefreshWorker::Runner
    SecurityGroupAmazon                        ManageIQ::Providers::Amazon::CloudManager::SecurityGroup
    TemplateAmazon                             ManageIQ::Providers::Amazon::CloudManager::Template
    VmAmazon                                   ManageIQ::Providers::Amazon::CloudManager::Vm

    ServiceOrchestration::OptionConverterAmazon
    ManageIQ::Providers::Amazon::CloudManager::OrchestrationServiceOptionConverter
  )]

  def change
    rename_class_references(NAME_MAP)
  end
end
