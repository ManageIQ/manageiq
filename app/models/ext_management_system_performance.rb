class ExtManagementSystemPerformance < MetricRollup
  default_scope { where("resource_type = 'ExtManagementSystem' and resource_id IS NOT NULL") }

  belongs_to :ext_management_system, :foreign_key => :resource_id
end
