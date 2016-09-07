require Rails.root.join('spec/shared/controllers/shared_examples_for_load_balancer_controller')

describe LoadBalancerController do
  include_examples :shared_examples_for_load_balancer_controller, %w()
end
