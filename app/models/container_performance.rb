class ContainerPerformance < MetricRollup
  default_scope { where "resource_type = 'Container' and resource_id IS NOT NULL" }

  belongs_to :container_node, :foreign_key => :resource_id, :class_name => Container.name
end
