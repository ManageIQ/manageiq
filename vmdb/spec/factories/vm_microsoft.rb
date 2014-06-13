FactoryGirl.define do
  factory :vm_microsoft do
    sequence(:name) { |n| "vm_#{n}" }
    location        { |x| "#{x.name}/#{x.name}.xml" }
    uid_ems         { MiqUUID.new_guid }
    vendor          "microsoft"
    template        false
    power_state     "on"
    cloud           false
  end
end
