FactoryGirl.define do
  factory :template_amazon, :class => "ManageIQ::Providers::Amazon::CloudManager::Template", :parent => :template_cloud do
    location { |x| "#{x.name}/#{x.name}.img.manifest.xml" }
    vendor   "amazon"
  end
end
