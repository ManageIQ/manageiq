FactoryGirl.define do
  factory :vm_redhat, :class => "ManageIQ::Providers::Redhat::InfraManager::Vm", :parent => :vm_infra do
    vendor          "redhat"
    raw_power_state "up"
  end
end
