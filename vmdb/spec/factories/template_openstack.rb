FactoryGirl.define do
  factory :template_openstack do
    sequence(:name) { |n| "template_#{n}" }
    location        "unknown"
    uid_ems         { MiqUUID.new_guid }
    vendor          "openstack"
    template        true
    raw_power_state "never"
    cloud           true
  end
end
