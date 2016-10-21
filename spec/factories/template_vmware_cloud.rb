FactoryGirl.define do
  factory :template_vmware_cloud,
          :class  => "ManageIQ::Providers::Vmware::CloudManager::Template",
          :parent => :template_cloud do
    vendor "vmware"
  end
end
