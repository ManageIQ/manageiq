FactoryGirl.define do
  factory :vm_amazon, :class => "VmAmazon", :parent => :vm_cloud do
    location { |x| "#{x.name}/#{x.name}.xml" }
    vendor   "amazon"
  end
end
