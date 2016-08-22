require Rails.root.join('spec/shared/controllers/shared_network_port_controller_spec')

describe NetworkPortController do
  include_examples :network_port_controller_spec, %w(openstack azure google)
end
