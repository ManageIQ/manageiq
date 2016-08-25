require Rails.root.join('spec/shared/controllers/shared_examples_for_floating_ip_controller')

describe FloatingIpController do
  include_examples :shared_examples_for_floating_ip_controller, %w(openstack azure google)
end
