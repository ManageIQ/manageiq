class StoragePerformance < MetricRollup
  default_scope { where "resource_type = 'Storage' and resource_id IS NOT NULL" }

  belongs_to :storage, :foreign_key => :resource_id
end
