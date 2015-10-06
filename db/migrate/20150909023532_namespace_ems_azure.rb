class NamespaceEmsAzure < ActiveRecord::Migration
  include MigrationHelper

  NAME_MAP = Hash[*%w(
    EmsAzure                                             ManageIQ::Providers::Azure::CloudManager
    AvailabilityZoneAzure                                ManageIQ::Providers::Azure::CloudManager::AvailabilityZone
    FlavorAzure                                          ManageIQ::Providers::Azure::CloudManager::Flavor
    EmsRefresh::Parsers::Azure                           ManageIQ::Providers::Azure::CloudManager::RefreshParser
    MiqEmsRefreshWorkerAzure                             ManageIQ::Providers::Azure::CloudManager::RefreshWorker
    EmsRefresh::Refreshers::AzureRefresher               ManageIQ::Providers::Azure::CloudManager::Refresher
    VmAzure                                              ManageIQ::Providers::Azure::CloudManager::Vm
  )]

  def change
    rename_class_references(NAME_MAP)
  end
end
