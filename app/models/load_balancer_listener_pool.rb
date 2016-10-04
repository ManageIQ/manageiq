class LoadBalancerListenerPool < ApplicationRecord
  include DtoMixin

  dto_manager_ref :load_balancer_listener, :load_balancer_pool

  belongs_to :load_balancer_listener
  belongs_to :load_balancer_pool
end
