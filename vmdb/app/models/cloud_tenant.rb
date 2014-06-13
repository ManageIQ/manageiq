class CloudTenant < ActiveRecord::Base
  attr_accessible :description, :ems_ref, :enabled, :name

  belongs_to      :ext_management_system, :foreign_key => "ems_id"
  has_many        :security_groups
  has_many        :cloud_networks
  has_many        :vms_and_templates
  has_many        :floating_ips
end
