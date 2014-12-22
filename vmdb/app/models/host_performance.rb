class HostPerformance < MetricRollup
  default_scope { where "resource_type = 'Host' and resource_id IS NOT NULL" }

  belongs_to :ems_cluster, :foreign_key => :parent_ems_cluster_id
  belongs_to :host,        :foreign_key => :resource_id
end
