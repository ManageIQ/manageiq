class ContainerGroupPerformance < MetricRollup
  default_scope { where("resource_type = 'ContainerGroup' and resource_id IS NOT NULL") }

  belongs_to :container_group, :foreign_key => :resource_id, :class_name => ContainerGroup.name

  def self.display_name(number = 1)
    n_('Pod Performance', 'Pod Performances', number)
  end
end
