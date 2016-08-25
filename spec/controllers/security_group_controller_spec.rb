require Rails.root.join('spec/shared/controllers/shared_examples_for_security_group_controller')

describe SecurityGroupController do
  include_examples :shared_examples_for_security_group_controller, %w(openstack azure google)
end
