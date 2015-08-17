class ManageIQ::Providers::Kubernetes::ContainerManager::Container < ::Container
  delegate :pod_uid, :to => :container_group
end
