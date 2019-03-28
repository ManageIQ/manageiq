class ContainerPerformance < MetricRollup
  default_scope { where("resource_type = 'Container' and resource_id IS NOT NULL") }

  belongs_to :container_node, :foreign_key => :resource_id, :class_name => "Container"

  def self.display_name(number = 1)
    n_('Performance - Container', 'Performance - Containers', number)
  end
end
