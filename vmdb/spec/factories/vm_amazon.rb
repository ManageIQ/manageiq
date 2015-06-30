FactoryGirl.define do
  factory :vm_amazon, :class => "ManageIQ::Providers::Amazon::CloudManager::Vm", :parent => :vm_cloud do
    location { |x| "#{x.name}.us-west-1.compute.amazonaws.com" }
    vendor   "amazon"
  end
end
