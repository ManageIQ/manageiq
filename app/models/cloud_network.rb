class CloudNetwork < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :cloud_tenant
  belongs_to :orchestration_stack
  has_many   :cloud_subnets, :dependent => :destroy
  has_many   :security_groups
  has_many   :vms

  # Use for virtual columns, mainly for modeling array and hash types, we get from the API
  serialize :extra_attributes
end
