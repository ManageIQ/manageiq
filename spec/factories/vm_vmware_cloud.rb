FactoryGirl.define do
  factory :vm_vmware_cloud, :class => "ManageIQ::Providers::Vmware::CloudManager::Vm", :parent => :vm_cloud do
    vendor          "vmware"
    raw_power_state "up"
  end
end
