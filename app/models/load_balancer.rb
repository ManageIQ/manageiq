class LoadBalancer < ApplicationRecord
  include NewWithTypeStiMixin
  include VirtualTotalMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  belongs_to :cloud_tenant

  has_many :load_balancer_health_checks
  has_many :load_balancer_listeners
  has_many :load_balancer_pools, :through => :load_balancer_listeners
  has_many :load_balancer_pool_members, -> { distinct }, :through => :load_balancer_pools

  has_many :network_ports
  has_many :cloud_subnet_network_ports, :through => :network_ports
  has_many :cloud_subnets, :through => :cloud_subnet_network_ports
  has_many :floating_ips, :through => :network_ports
  has_many :security_groups, -> { distinct }, :through => :network_ports

  has_many :vms, -> { distinct }, :through => :load_balancer_pool_members
  has_many :resource_groups, -> { distinct }, :through => :load_balancer_pool_members

  virtual_total :total_vms, :vms, :uses => :vms
end
