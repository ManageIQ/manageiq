class ContainerProjectPerformance < MetricRollup
  default_scope { where(:resource_type => 'ContainerProject').where.not(:resource_id => nil) }

  belongs_to :container_node, :foreign_key => :resource_id, :class_name => "ContainerProject"

  def self.display_name(number = 1)
    n_('Performance - Container Project', 'Performance - Container Projects', number)
  end
end
