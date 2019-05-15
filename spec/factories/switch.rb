FactoryBot.define do
  factory :switch # generic needed for transformation_mapping_item_spec.rb
  factory :switch_vmware, :class => 'ManageIQ::Providers::Vmware::InfraManager::HostVirtualSwitch', :parent => :switch
end
