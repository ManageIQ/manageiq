FactoryGirl.define do
  factory :vm_redhat, :class => "VmRedhat", :parent => :vm_infra do
    vendor          "redhat"
    raw_power_state "up"
  end
end
