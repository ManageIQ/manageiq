class ContainerGroupKubernetes < ContainerGroup
  alias_attribute :pod_uid, :ems_ref
end
