FactoryGirl.define do
  factory :virtual_template, :class => 'ManageIQ::Providers::CloudManager::VirtualTemplate' do
    name                    'a virtual template'
    description             'stores all arbitration decisions'
    ext_management_system   { FactoryGirl.create(:ems_cloud) }
  end

  factory :virtual_template_amazon, :class => 'ManageIQ::Providers::Amazon::CloudManager::VirtualTemplate' do
    name                    'virtual template amazon'
    description             'a virtual template for amazon'
    ext_management_system   { FactoryGirl.create(:ems_amazon) }
  end

  factory :virtual_template_google, :class => 'ManageIQ::Providers::Google::CloudManager::VirtualTemplate' do
    name                    'virtual template google'
    description             'a virtual template for google'
    ext_management_system   { FactoryGirl.create(:ems_google) }
  end
end
