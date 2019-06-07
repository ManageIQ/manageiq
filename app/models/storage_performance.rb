class StoragePerformance < MetricRollup
  default_scope { where(:resource_type => 'Storage').where.not(:resource_id => nil) }

  belongs_to :storage, :foreign_key => :resource_id

  def self.display_name(number = 1)
    n_('Performance - Datastore', 'Performance - Datastores', number)
  end
end
