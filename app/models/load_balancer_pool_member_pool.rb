class LoadBalancerPoolMemberPool < ApplicationRecord
  belongs_to :load_balancer_pool
  belongs_to :load_balancer_pool_member
end
