FactoryGirl.define do
  factory :vm_google, :class => "ManageIQ::Providers::Google::CloudManager::Vm", :parent => :vm_cloud do
    vendor "google"
  end
end
