class ExtManagementSystemPerformance < MetricRollup
  default_scope { where(:resource_type => 'ExtManagementSystem').where.not(:resource_id => nil) }

  belongs_to :ext_management_system, :foreign_key => :resource_id

  def self.display_name(number = 1)
    n_('Performance - Provider', 'Performance - Providers', number)
  end
end
