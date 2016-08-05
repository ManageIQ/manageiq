class LoadBalancerHealthCheck < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  belongs_to :cloud_tenant
  belongs_to :load_balancer
  belongs_to :load_balancer_listener

  has_many :load_balancer_pool_members, :through => :load_balancer_health_check_members
end