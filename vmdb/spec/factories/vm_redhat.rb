FactoryGirl.define do
  factory :vm_redhat do
    sequence(:name) { |n| "vm_#{seq_padded_for_sorting(n)}" }
    location        { |x| "[storage] #{x.name}/#{x.name}.vmx" }
    uid_ems         { MiqUUID.new_guid }
    vendor          "redhat"
    raw_power_state "up"
    template        false
  end
end
