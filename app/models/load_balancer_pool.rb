class LoadBalancerPool < ApplicationRecord
  include NewWithTypeStiMixin
  include VirtualTotalMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  belongs_to :cloud_tenant

  has_many :load_balancer_listener_pools, :dependent => :destroy
  has_many :load_balancer_listeners, :through => :load_balancer_listener_pools
  has_many :load_balancer_pool_member_pools, :dependent => :destroy
  has_many :load_balancer_pool_members, :through => :load_balancer_pool_member_pools

  virtual_total :total_vms, :vms, :uses => :vms
end
