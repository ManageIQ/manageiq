require Rails.root.join('spec/shared/controllers/shared_security_group_controller_spec')

describe SecurityGroupController do
  include_examples :security_group_controller_spec, %w(openstack azure google)
end
