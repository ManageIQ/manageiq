FactoryGirl.define do
  factory :template_amazon do
    sequence(:name) { |n| "template_#{n}" }
    location        { |x| "#{x.name}/#{x.name}.xml" }
    uid_ems         { MiqUUID.new_guid }
    vendor          "amazon"
    template        true
    raw_power_state "never"
    cloud           true
  end
end
