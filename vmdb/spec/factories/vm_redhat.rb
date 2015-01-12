FactoryGirl.define do
  factory :vm_redhat, :class => "VmRedhat", :parent => :vm_infra do
    location        { |x| "[storage] #{x.name}/#{x.name}.vmx" }
    vendor          "redhat"
    raw_power_state "up"
  end
end
