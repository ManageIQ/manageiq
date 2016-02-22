FactoryGirl.define do
  factory :vm_azure, :class => "ManageIQ::Providers::Azure::CloudManager::Vm", :parent => :vm_cloud do
    location "westus"
    vendor   "azure"
    uid_ems  "01234567890\\test_resource_group\\microsoft.resources\\vm_1"
    ems_ref  "01234567890\\test_resource_group\\microsoft.resources\\vm_1"
    raw_power_state "VM running"
    name "vm_1"
  end
end
