FactoryGirl.define do
  factory :virtual_template, :class => 'ManageIQ::Providers::CloudManager::VirtualTemplate' do
    vendor                  'amazon'
    name                    'vt'
    location                'us-west-1'
    ems_ref                 'i-12345'
  end

  factory :virtual_template_amazon, :class => 'ManageIQ::Providers::Amazon::CloudManager::VirtualTemplate' do
    vendor                  'amazon'
    name                    'virtual template amazon'
    location                'us-west-1'
    ems_ref                 'i-12345'
  end

  factory :virtual_template_google, :class => 'ManageIQ::Providers::Google::CloudManager::VirtualTemplate' do
    vendor                  'google'
    name                    'virtual template google'
    location                'us-west-1'
    ems_ref                 'i-12345'
  end
end
