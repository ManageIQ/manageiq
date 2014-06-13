FactoryGirl.define do
  factory :template_openstack do
    sequence(:name) { |n| "template_#{n}" }
    location        "unknown"
    uid_ems         { MiqUUID.new_guid }
    vendor          "openstack"
    template        true
    state           "never"
    cloud           true
  end
end
