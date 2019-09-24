class CloudDatabase < ApplicationRecord
  include NewWithTypeStiMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :cloud_tenant
  belongs_to :cloud_database_flavor
  belongs_to :resource_group

  serialize :extra_attributes
end
