require Rails.root.join('spec/shared/controllers/shared_examples_for_ems_object_storage_controller')

describe EmsObjectStorageController do
  include_examples :shared_examples_for_ems_object_storage_controller, %w(openstack)
end
