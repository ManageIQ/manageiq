class NetworkPort < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :cloud_tenant
  belongs_to :cloud_network
  belongs_to :cloud_subnet
  belongs_to :device, :polymorphic => true

  has_and_belongs_to_many :security_groups

  has_many :floating_ips

  # Use for virtual columns, mainly for modeling array and hash types, we get from the API
  serialize :extra_attributes
end
