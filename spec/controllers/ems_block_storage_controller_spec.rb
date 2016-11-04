require Rails.root.join('spec/shared/controllers/shared_examples_for_ems_block_storage_controller')

describe EmsBlockStorageController do
  include_examples :shared_examples_for_ems_block_storage_controller, %w(openstack)
end
