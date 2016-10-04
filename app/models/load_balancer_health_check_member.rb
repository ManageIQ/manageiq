class LoadBalancerHealthCheckMember < ApplicationRecord
  include DtoMixin
  dto_manager_ref :load_balancer_health_check, :load_balancer_pool_member

  belongs_to :load_balancer_health_check
  belongs_to :load_balancer_pool_member
end
