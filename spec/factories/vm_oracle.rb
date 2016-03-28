FactoryGirl.define do
  factory :vm_oracle, :class => "ManageIQ::Providers::Oracle::InfraManager::Vm", :parent => :vm_infra do
    vendor          "oracle"
    raw_power_state "RUNNING"
  end
end
