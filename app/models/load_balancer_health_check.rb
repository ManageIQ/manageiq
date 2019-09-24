class LoadBalancerHealthCheck < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  belongs_to :cloud_tenant
  belongs_to :load_balancer
  belongs_to :load_balancer_listener

  has_many :load_balancer_health_check_members, -> { distinct }, :dependent => :destroy
  has_many :load_balancer_pool_members, :through => :load_balancer_health_check_members

  has_many :vms, -> { distinct }, :through => :load_balancer_pool_members
  has_many :resource_groups, -> { distinct }, :through => :load_balancer_pool_members

  virtual_total :total_vms, :vms, :uses => :vms
end
