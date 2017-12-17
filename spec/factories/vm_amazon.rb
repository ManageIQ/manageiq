FactoryGirl.define do
  factory :vm_amazon, :class => "ManageIQ::Providers::Amazon::CloudManager::Vm", :parent => :vm_cloud do
    location { |x| "#{x.name}.us-west-1.compute.amazonaws.com" }
    vendor   "amazon"

    trait :with_provider do
      after(:create) do |x|
        FactoryGirl.create(:ems_amazon, :vms => [x])
      end
    end

    trait :powered_off do
      raw_power_state "stopped"
    end
  end
end
