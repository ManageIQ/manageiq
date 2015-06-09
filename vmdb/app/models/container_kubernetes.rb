class ContainerKubernetes < Container
  delegate :pod_uid, :to => :container_group
end
