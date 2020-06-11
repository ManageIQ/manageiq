FactoryBot.define do
  factory :cloud_tenant do
    sequence(:name)         { |n| "cloud_tenant_#{seq_padded_for_sorting(n)}" }
    sequence(:description)  { |n| "cloud_tenant_description_#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref)      { |n| "ems_ref_#{seq_padded_for_sorting(n)}" }
  end

  factory :cloud_tenant_openstack,
          :class => "ManageIQ::Providers::Openstack::CloudManager::CloudTenant",
          :parent => :cloud_tenant
  factory :cloud_tenant_nsxt,
          :class => "ManageIQ::Providers::Nsxt::CloudManager::CloudTenant",
          :parent => :cloud_tenant
end
