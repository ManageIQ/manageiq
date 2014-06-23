class CloudResourceQuota < ActiveRecord::Base
  # plural of "quota" is "quota" ... overriding here to be "quotas"
  self.table_name = "cloud_resource_quotas"

  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :cloud_tenant
end
