FactoryGirl.define do
  factory :vm_amazon do
    sequence(:name) { |n| "vm_#{n}" }
    location        { |x| "#{x.name}/#{x.name}.xml" }
    uid_ems         { MiqUUID.new_guid }
    vendor          "amazon"
    template        false
    power_state     "on"
    cloud           true
  end
end
