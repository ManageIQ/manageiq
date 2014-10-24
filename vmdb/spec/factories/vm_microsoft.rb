FactoryGirl.define do
  factory :vm_microsoft do
    sequence(:name) { |n| "vm_#{seq_padded_for_sorting(n)}" }
    location        { |x| "#{x.name}/#{x.name}.xml" }
    uid_ems         { MiqUUID.new_guid }
    vendor          "microsoft"
    template        false
    raw_power_state "Running"
    cloud           false
  end
end
