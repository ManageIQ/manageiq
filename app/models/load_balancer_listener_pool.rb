class LoadBalancerListenerPool < ApplicationRecord
  belongs_to :load_balancer_listener
  belongs_to :load_balancer_pool
end
