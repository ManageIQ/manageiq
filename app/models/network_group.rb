class NetworkGroup < ApplicationRecord
  include NewWithTypeStiMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :orchestration_stack

  has_many :cloud_subnets, :dependent => :destroy
  has_many :network_ports, :through => :cloud_subnets
  has_many :network_routers, :dependent => :destroy
  has_many :security_groups, :dependent => :destroy
end
