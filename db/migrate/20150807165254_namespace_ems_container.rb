class NamespaceEmsContainer < ActiveRecord::Migration
  include MigrationHelper

  NAME_MAP = Hash[*%w(
    EmsKubernetes                     ManageIQ::Providers::Kubernetes::ContainerManager
    ContainerKubernetes               ManageIQ::Providers::Kubernetes::ContainerManager::Container
    ContainerGroupKubernetes          ManageIQ::Providers::Kubernetes::ContainerManager::ContainerGroup
    ContainerNodeKubernetes           ManageIQ::Providers::Kubernetes::ContainerManager::ContainerNode
    MiqEventCatcherKubernetes         ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcher
    EventCatcherKubernetes            ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcher::Runner
    MiqEmsRefreshWorkerKubernetes     ManageIQ::Providers::Kubernetes::ContainerManager::RefreshWorker
    EmsRefreshWorkerKubernetes        ManageIQ::Providers::Kubernetes::ContainerManager::RefreshWorker::Runner

    EmsOpenshift                      ManageIQ::Providers::Openshift::ContainerManager
    MiqEventCatcherOpenshift          ManageIQ::Providers::Openshift::ContainerManager::EventCatcher
    EventCatcherOpenshift             ManageIQ::Providers::Openshift::ContainerManager::EventCatcher::Runner
    MiqEmsRefreshWorkerOpenshift      ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker
    EmsRefreshWorkerOpenshift         ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker::Runner
  )]

  def change
    rename_class_references(NAME_MAP)
  end
end
