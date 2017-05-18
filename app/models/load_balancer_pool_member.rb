class LoadBalancerPoolMember < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  belongs_to :cloud_tenant
  belongs_to :resource_group
  belongs_to :network_port
  belongs_to :vm

  has_many :load_balancer_health_check_members, :dependent => :destroy
  has_many :load_balancer_health_checks, :through => :load_balancer_health_check_members
  has_many :load_balancer_pool_member_pools, :dependent => :destroy
  has_many :load_balancer_pools, :through => :load_balancer_pool_member_pools

  has_many :load_balancer_listeners, -> { distinct }, :through => :load_balancer_pools
  has_many :load_balancers, -> { distinct }, :through => :load_balancer_listeners

  virtual_column :load_balancer_health_check_states, :type => :string_set, :uses => :load_balancer_health_check_members
  virtual_column :load_balancer_health_check_states_with_reason,
                 :type => :string_set,
                 :uses => :load_balancer_health_check_members

  virtual_total :total_vms, :vms, :uses => :vms

  def load_balancer_health_check_states
    @load_balancer_health_check_states ||= load_balancer_health_check_members.collect(&:status)
  end

  def load_balancer_health_check_states_with_reason
    @load_balancer_health_check_states_with_reason ||= load_balancer_health_check_members.collect do |x|
      "Status: #{x.status}, Status Reason: #{x.status_reason}"
    end
  end
end
