require Rails.root.join('spec/shared/controllers/shared_network_router_controller_spec')

describe NetworkRouterController do
  include_examples :network_router_controller_spec, %w(openstack azure google)
end
