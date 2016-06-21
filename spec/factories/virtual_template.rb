FactoryGirl.define do
  factory(:virtual_template, class: 'ManageIQ::Providers::CloudManager::VirtualTemplate')

  trait :amazon do
    vendor :amazon
    name 'amazonVirtual'
    location 'us-west-2'
    ems_ref 'i-12345'
    availability_zone_id 0
    cloud_subnet_id 1
    cloud_network_id 2
  end
end