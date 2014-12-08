class EmsClusterPerformance < MetricRollup
  default_scope { where "resource_type = 'EmsCluster' and resource_id IS NOT NULL" }

  belongs_to :ems_cluster, :foreign_key => :resource_id
end
