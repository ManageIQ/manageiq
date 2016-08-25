require Rails.root.join('spec/shared/controllers/shared_examples_for_cloud_network_controller')

describe CloudNetworkController do
  include_examples :shared_examples_for_cloud_network_controller, %w(openstack azure google)
end
