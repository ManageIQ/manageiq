class LoadBalancerPoolMember < ApplicationRecord
  belongs_to :load_balancer_pool
  belongs_to :cloud_tenant
  belongs_to :resource_group

  has_many :load_balancer_health_checks, :through => :load_balancer_health_check_members
end
