require Rails.root.join('spec/shared/controllers/shared_examples_for_ems_network_controller')

describe EmsNetworkController do
  include_examples :shared_examples_for_ems_network_controller, %w(openstack azure google)
end
