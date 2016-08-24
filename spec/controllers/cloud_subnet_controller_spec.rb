require Rails.root.join('spec/shared/controllers/shared_cloud_subnet_controller_spec')

describe CloudSubnetController do
  include_examples :cloud_subnet_controller_spec, %w(openstack azure google)
end
