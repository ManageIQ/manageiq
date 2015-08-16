class ManageIQ::Providers::Kubernetes::ContainerManager::Container < ::Container
  has_one :pod_uid, through: :container_group
end
