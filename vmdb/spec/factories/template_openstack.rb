FactoryGirl.define do
  factory :template_openstack do
    sequence(:name) { |n| "template_#{seq_padded_for_sorting(n)}" }
    location        "unknown"
    uid_ems         { MiqUUID.new_guid }
    vendor          "openstack"
    template        true
    raw_power_state "never"
    cloud           true
  end
end
