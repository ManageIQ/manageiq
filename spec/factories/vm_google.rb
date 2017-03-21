FactoryGirl.define do
  factory :vm_google, :class => "ManageIQ::Providers::Google::CloudManager::Vm", :parent => :vm_cloud do
    vendor "google"

    trait :with_provider do
      after(:create) do |x|
        FactoryGirl.create(:ems_google, :vms => [x])
      end
    end
  end
end
