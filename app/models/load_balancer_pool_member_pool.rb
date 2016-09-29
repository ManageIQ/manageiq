class LoadBalancerPoolMemberPool < ApplicationRecord
  belongs_to :load_balancer_pool
  belongs_to :load_balancer_pool_member

  include DtoMixin
  dto_manager_ref :load_balancer_pool, :load_balancer_pool_member
  dto_attributes :load_balancer_pool, :load_balancer_pool_member
  dto_dependencies :load_balancer_pools, :load_balancer_pool_members
end
