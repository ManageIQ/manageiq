class LoadBalancerListener < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  belongs_to :cloud_tenant
  belongs_to :load_balancer

  has_many :load_balancer_listener_pools
  has_many :load_balancer_pools, :through => :load_balancer_listener_pools
  has_many :load_balancer_pool_members, :through => :load_balancer_pools
end