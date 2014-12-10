class CloudNetwork < ActiveRecord::Base
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "Ems::CloudProvider"
  belongs_to :cloud_tenant
  belongs_to :orchestration_stack
  has_many   :cloud_subnets, :dependent => :destroy
  has_many   :security_groups
  has_many   :vms
end
