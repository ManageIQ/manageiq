require Rails.root.join('spec/shared/controllers/shared_load_balancer_controller_spec')

describe LoadBalancerController do
  include_examples :load_balancer_controller_spec, %w()
end
