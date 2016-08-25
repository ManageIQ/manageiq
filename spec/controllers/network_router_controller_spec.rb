require Rails.root.join('spec/shared/controllers/shared_examples_for_network_router_controller')

describe NetworkRouterController do
  include_examples :shared_examples_for_network_router_controller, %w(openstack azure google)
end
