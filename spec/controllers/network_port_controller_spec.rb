require Rails.root.join('spec/shared/controllers/shared_examples_for_network_port_controller')

describe NetworkPortController do
  include_examples :shared_examples_for_network_port_controller, %w(openstack azure google)
end
