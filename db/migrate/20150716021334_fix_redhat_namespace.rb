class FixRedhatNamespace < ActiveRecord::Migration
  include MigrationHelper

  NAME_MAP = Hash[*%w(
    ManageIQ::Providers::Redhat::CloudManager
    ManageIQ::Providers::Redhat::InfraManager
    ManageIQ::Providers::Redhat::CloudManager::EventCatcher
    ManageIQ::Providers::Redhat::InfraManager::EventCatcher
    ManageIQ::Providers::Redhat::CloudManager::EventCatcher::Runner
    ManageIQ::Providers::Redhat::InfraManager::EventCatcher::Runner
    ManageIQ::Providers::Redhat::CloudManager::MetricsCollectorWorker
    ManageIQ::Providers::Redhat::InfraManager::MetricsCollectorWorker
    ManageIQ::Providers::Redhat::CloudManager::MetricsCollectorWorker::Runner
    ManageIQ::Providers::Redhat::InfraManager::MetricsCollectorWorker::Runner
    ManageIQ::Providers::Redhat::CloudManager::RefreshWorker
    ManageIQ::Providers::Redhat::InfraManager::RefreshWorker
    ManageIQ::Providers::Redhat::CloudManager::RefreshWorker::Runner
    ManageIQ::Providers::Redhat::InfraManager::RefreshWorker::Runner
    ManageIQ::Providers::Redhat::CloudManager::Template
    ManageIQ::Providers::Redhat::InfraManager::Template
    ManageIQ::Providers::Redhat::CloudManager::Vm
    ManageIQ::Providers::Redhat::InfraManager::Vm

    HostRedhat                             ManageIQ::Providers::Redhat::InfraManager::Host
  )]

  def change
    rename_class_references(NAME_MAP)
  end
end
