require Rails.root.join('spec/shared/controllers/shared_examples_for_cloud_subnet_controller')

describe CloudSubnetController do
  include_examples :shared_examples_for_cloud_subnet_controller, %w(openstack azure google)
end
