FactoryGirl.define do
  factory :vm_redhat do
    sequence(:name) { |n| "vm_#{n}" }
    location        { |x| "[storage] #{x.name}/#{x.name}.vmx" }
    uid_ems         { MiqUUID.new_guid }
    vendor          "redhat"
    power_state     "on"
    template        false
  end
end
