class NamespaceEmsMicrosoft < ActiveRecord::Migration
  include MigrationHelper

  NAME_MAP = Hash[*%w(
    EmsMicrosoft                     ManageIQ::Providers::Microsoft::InfraManager
    HostMicrosoft                    ManageIQ::Providers::Microsoft::InfraManager::Host
    MiqEmsRefreshWorkerMicrosoft     ManageIQ::Providers::Microsoft::InfraManager::RefreshWorker
    EmsRefreshWorkerMicrosoft        ManageIQ::Providers::Microsoft::InfraManager::RefreshWorker::Runner
    TemplateMicrosoft                ManageIQ::Providers::Microsoft::InfraManager::Template
    VmMicrosoft                      ManageIQ::Providers::Microsoft::InfraManager::Vm
  )]

  def change
    say_with_time "Rename class references for Microsoft SCVMM" do
      rename_class_references(NAME_MAP)
    end
  end
end
