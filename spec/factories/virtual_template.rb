FactoryGirl.define do
  factory :virtual_template, class: 'ManageIQ::Providers::CloudManager::VirtualTemplate' do
    vendor 'amazon'
    name 'vt'
    location 'us-west-1'
    ems_ref 'i-12345'
    availability_zone_id 0
    cloud_subnet_id 1
    cloud_network_id 2
  end
end