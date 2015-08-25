class ManageIQ::Providers::Kubernetes::ContainerManager::ContainerGroup < ::ContainerGroup
  alias_attribute :pod_uid, :ems_ref
end
