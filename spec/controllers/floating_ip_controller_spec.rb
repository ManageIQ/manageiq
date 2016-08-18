require Rails.root.join('spec/shared/controllers/shared_floating_ip_controller_spec')

describe FloatingIpController do
  include_examples :floating_ip_controller_spec, %w(openstack azure google)
end
