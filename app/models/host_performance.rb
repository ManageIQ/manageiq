class HostPerformance < MetricRollup
  default_scope { where(:resource_type => 'Host').where.not(:resource_id => nil) }

  belongs_to :ems_cluster, :foreign_key => :parent_ems_cluster_id
  belongs_to :host,        :foreign_key => :resource_id

  def self.display_name(number = 1)
    n_('Performance - Host', 'Performance - Hosts', number)
  end
end
