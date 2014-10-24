FactoryGirl.define do
  factory :template_redhat do
    sequence(:name) { |n| "template_#{seq_padded_for_sorting(n)}" }
    location        { |x| "[storage] #{x.name}/#{x.name}.vmtx" }
    uid_ems         { MiqUUID.new_guid }
    vendor          "redhat"
    template        true
    raw_power_state "never"
  end
end
