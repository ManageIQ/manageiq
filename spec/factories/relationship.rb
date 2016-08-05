FactoryGirl.define do
  factory :relationship do
    resource_type  "VmOrTemplate"
  end

  factory :relationship_vm_vmware, :parent => :relationship do
    resource_type  "VmOrTemplate"
  end

  factory :relationship_host_vmware, :parent => :relationship do
    resource_type  "Host"
  end

  factory :relationship_storage_vmware, :parent => :relationship do
    resource_type  "Storage"
  end
end
