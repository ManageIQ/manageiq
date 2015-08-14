class ManageIQ::Providers::Openshift::ContainerManager::EventCatcher::Runner < ManageIQ::Providers::BaseManager::EventCatcher::Runner
  include ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcherMixin
end
