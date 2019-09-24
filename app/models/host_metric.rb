class HostMetric < Metric
  default_scope { where(:resource_type => 'Host').where.not(:resource_id => nil) }

  belongs_to                :host,        :foreign_key => :resource_id
  belongs_to                :ems_cluster, :foreign_key => :parent_ems_cluster_id
end
