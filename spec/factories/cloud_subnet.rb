FactoryGirl.define do
  factory :cloud_subnet do
    sequence(:name)    { |n| "cloud_subnet_#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref) { |n| "ems_ref_#{seq_padded_for_sorting(n)}" }
  end

  factory :cloud_subnet_openstack, :class  => "ManageIQ::Providers::Openstack::CloudManager::CloudSubnet",
                                   :parent => :cloud_subnet
end
