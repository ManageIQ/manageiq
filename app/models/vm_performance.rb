class VmPerformance < MetricRollup
  default_scope { where(:resource_type => 'VmOrTemplate').where.not(:resource_id => nil) }

  belongs_to :host,        :foreign_key => :parent_host_id
  belongs_to :ems_cluster, :foreign_key => :parent_ems_cluster_id
  belongs_to :storage,     :foreign_key => :parent_storage_id
  belongs_to :vm,          :foreign_key => :resource_id, :class_name => 'VmOrTemplate'

  def self.display_name(number = 1)
    n_('Performance - VM', 'Performance - VMs', number)
  end
end
