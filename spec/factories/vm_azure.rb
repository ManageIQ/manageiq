FactoryGirl.define do
  factory :vm_azure, :class => "ManageIQ::Providers::Azure::CloudManager::Vm", :parent => :vm_cloud do
    location "westus"
    vendor   "azure"
    raw_power_state "VM running"
  end
end
