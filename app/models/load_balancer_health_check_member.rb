class LoadBalancerHealthCheckMember < ApplicationRecord
  belongs_to :load_balancer_health_check
  belongs_to :load_balancer_pool_member
end
