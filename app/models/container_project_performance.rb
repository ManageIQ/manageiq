class ContainerProjectPerformance < MetricRollup
  default_scope { where "resource_type = 'ContainerProject' and resource_id IS NOT NULL" }

  belongs_to :container_node, :foreign_key => :resource_id, :class_name => ContainerProject.name
end
