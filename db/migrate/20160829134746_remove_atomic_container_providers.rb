class RemoveAtomicContainerProviders < ActiveRecord::Migration[5.0]
  include MigrationHelper

  NAME_MAP = Hash[*%w(
    ManageIQ::Providers::Atomic::ContainerManager                                 ManageIQ::Providers::Openshift::ContainerManager
    ManageIQ::Providers::Atomic::ContainerManager::EventCatcher                   ManageIQ::Providers::Openshift::ContainerManager::EventCatcher
    ManageIQ::Providers::Atomic::ContainerManager::EventCatcher::Runner           ManageIQ::Providers::Openshift::ContainerManager::EventCatcher::Runner
    ManageIQ::Providers::Atomic::ContainerManager::EventParser                    ManageIQ::Providers::Openshift::ContainerManager::EventParser
    ManageIQ::Providers::Atomic::ContainerManager::MetricsCollectorWorker         ManageIQ::Providers::Openshift::ContainerManager::MetricsCollectorWorker
    ManageIQ::Providers::Atomic::ContainerManager::MetricsCollectorWorker::Runner ManageIQ::Providers::Openshift::ContainerManager::MetricsCollectorWorker::Runner
    ManageIQ::Providers::Atomic::ContainerManager::RefreshParser                  ManageIQ::Providers::Openshift::ContainerManager::RefreshParser
    ManageIQ::Providers::Atomic::ContainerManager::RefreshWorker                  ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker
    ManageIQ::Providers::Atomic::ContainerManager::RefreshWorker::Runner          ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker::Runner
    ManageIQ::Providers::Atomic::ContainerManager::Refresher                      ManageIQ::Providers::Openshift::ContainerManager::Refresher

    ManageIQ::Providers::AtomicEnterprise::ContainerManager                                 ManageIQ::Providers::OpenshiftEnterprise::ContainerManager
    ManageIQ::Providers::AtomicEnterprise::ContainerManager::EventCatcher                   ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::EventCatcher
    ManageIQ::Providers::AtomicEnterprise::ContainerManager::EventCatcher::Runner           ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::EventCatcher::Runner
    ManageIQ::Providers::AtomicEnterprise::ContainerManager::EventParser                    ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::EventParser
    ManageIQ::Providers::AtomicEnterprise::ContainerManager::MetricsCollectorWorker         ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::MetricsCollectorWorker
    ManageIQ::Providers::AtomicEnterprise::ContainerManager::MetricsCollectorWorker::Runner ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::MetricsCollectorWorker::Runner
    ManageIQ::Providers::AtomicEnterprise::ContainerManager::RefreshParser                  ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::RefreshParser
    ManageIQ::Providers::AtomicEnterprise::ContainerManager::RefreshWorker                  ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::RefreshWorker
    ManageIQ::Providers::AtomicEnterprise::ContainerManager::RefreshWorker::Runner          ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::RefreshWorker::Runner
    ManageIQ::Providers::AtomicEnterprise::ContainerManager::Refresher                      ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::Refresher
  )]

  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class MiqWorker < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class Authentication < ActiveRecord::Base; end
  class MiqQueue < ActiveRecord::Base; end

  def up
    say_with_time "Rename class references for Atomic and AtomicEnterprise" do
      rename_class_references(NAME_MAP)
    end

    say_with_time "Rename Atomic to Openshift in Authentication:name" do
      Authentication.update_all("name = replace(name, 'ManageIQ::Providers::Atomic', 'ManageIQ::Providers::Openshift')")
    end

    say_with_time "Rename Atomic to Openshift in MiqQueue:args" do
      MiqQueue.update_all("args = replace(args, 'ManageIQ::Providers::Atomic', 'ManageIQ::Providers::Openshift')")
    end
  end
end
