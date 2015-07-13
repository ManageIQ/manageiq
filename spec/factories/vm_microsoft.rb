FactoryGirl.define do
  factory :vm_microsoft, :class => "VmMicrosoft", :parent => :vm_infra do
    location        { |x| "#{x.name}/#{x.name}.xml" }
    vendor          "microsoft"
    raw_power_state "Running"
  end
end
