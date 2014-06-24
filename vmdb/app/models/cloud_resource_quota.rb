class CloudResourceQuota < ActiveRecord::Base
  attr_accessible :ems_ref, :service_name, :name, :value, :type, :cloud_tenant_id

  # plural of "quota" is "quota" ... overriding here to be "quotas"
  self.table_name = "cloud_resource_quotas"

  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :cloud_tenant
end
