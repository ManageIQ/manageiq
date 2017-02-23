class RemoveOpenshiftEnterpriseProvider < ActiveRecord::Migration[5.0]
  include MigrationHelper

  NAME_MAP = Hash[*%w(
    ManageIQ::Providers::OpenshiftEnterprise::ContainerManager                                 ManageIQ::Providers::Openshift::ContainerManager
    ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::EventCatcher                   ManageIQ::Providers::Openshift::ContainerManager::EventCatcher
    ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::EventCatcher::Runner           ManageIQ::Providers::Openshift::ContainerManager::EventCatcher::Runner
    ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::EventParser                    ManageIQ::Providers::Openshift::ContainerManager::EventParser
    ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::MetricsCollectorWorker         ManageIQ::Providers::Openshift::ContainerManager::MetricsCollectorWorker
    ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::MetricsCollectorWorker::Runner ManageIQ::Providers::Openshift::ContainerManager::MetricsCollectorWorker::Runner
    ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::RefreshParser                  ManageIQ::Providers::Openshift::ContainerManager::RefreshParser
    ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::RefreshWorker                  ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker
    ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::RefreshWorker::Runner          ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker::Runner
    ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::Refresher                      ManageIQ::Providers::Openshift::ContainerManager::Refresher
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
    say_with_time "Rename class references for Openshift and OpenshiftEnterprise" do
      rename_class_references(NAME_MAP)
    end

    say_with_time "Rename Openshift to Openshift in Authentication:name" do
      Authentication.update_all("name = replace(name, 'ManageIQ::Providers::OpenshiftEnterprise', 'ManageIQ::Providers::Openshift')")
    end

    say_with_time "Rename Openshift to Openshift in MiqQueue:args" do
      MiqQueue.update_all("args = replace(args, 'ManageIQ::Providers::OpenshiftEnterprise', 'ManageIQ::Providers::Openshift')")
    end
  end
end
