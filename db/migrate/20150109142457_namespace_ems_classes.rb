class NamespaceEmsClasses < ActiveRecord::Migration
  include MigrationHelper

  NAME_MAP = Hash[*%w(
    EmsCloud                               ManageIQ::Providers::CloudManager
    HostCloud                              ManageIQ::Providers::CloudManager::Host
    TemplateCloud                          ManageIQ::Providers::CloudManager::Template
    VmCloud                                ManageIQ::Providers::CloudManager::Vm

    EmsInfra                               ManageIQ::Providers::InfraManager
    HostInfra                              ManageIQ::Providers::InfraManager::Host
    TemplateInfra                          ManageIQ::Providers::InfraManager::Template
    VmInfra                                ManageIQ::Providers::InfraManager::Vm

    EmsVmware                              ManageIQ::Providers::Vmware::InfraManager
    MiqEventCatcherVmware                  ManageIQ::Providers::Vmware::InfraManager::EventCatcher
    EventCatcherVmware                     ManageIQ::Providers::Vmware::InfraManager::EventCatcher::Runner
    HostVmware                             ManageIQ::Providers::Vmware::InfraManager::Host
    HostVmwareEsx                          ManageIQ::Providers::Vmware::InfraManager::HostEsx
    MiqEmsMetricsCollectorWorkerVmware     ManageIQ::Providers::Vmware::InfraManager::MetricsCollectorWorker
    EmsMetricsCollectorWorkerVmware        ManageIQ::Providers::Vmware::InfraManager::MetricsCollectorWorker::Runner
    MiqEmsRefreshWorkerVmware              ManageIQ::Providers::Vmware::InfraManager::RefreshWorker
    EmsRefreshWorkerVmware                 ManageIQ::Providers::Vmware::InfraManager::RefreshWorker::Runner
    TemplateVmware                         ManageIQ::Providers::Vmware::InfraManager::Template
    VmVmware                               ManageIQ::Providers::Vmware::InfraManager::Vm
  )]

  def change
    rename_class_references(NAME_MAP)
  end
end
