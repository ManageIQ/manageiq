FactoryGirl.define do
  factory :vm_amazon, :class => "ManageIQ::Providers::Amazon::CloudManager::Vm", :parent => :vm_cloud do
    location { |x| "#{x.name}.us-west-1.compute.amazonaws.com" }
    vendor   "amazon"

    trait :with_provider do
      after(:create) do |x|
        FactoryGirl.create(:ems_amazon, :vms => [x])
      end
    end
  end

  factory :vm_perf_amazon, :parent => :vm_amazon do
    ems_ref "amazon-perf-vm"
  end
end
