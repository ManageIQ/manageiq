class NetworkRouter < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :cloud_tenant
  belongs_to :cloud_network

  has_many :floating_ips
  has_many :network_ports, :as => :device

  # Use for virtual columns, mainly for modeling array and hash types, we get from the API
  serialize :extra_attributes
end
