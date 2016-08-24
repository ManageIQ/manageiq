require Rails.root.join('spec/shared/controllers/shared_cloud_network_controller_spec')

describe CloudNetworkController do
  include_examples :cloud_network_controller_spec, %w(openstack azure google)
end
