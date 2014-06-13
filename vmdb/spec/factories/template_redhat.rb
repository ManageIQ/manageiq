FactoryGirl.define do
  factory :template_redhat do
    sequence(:name) { |n| "template_#{n}" }
    location        { |x| "[storage] #{x.name}/#{x.name}.vmtx" }
    uid_ems         { MiqUUID.new_guid }
    vendor          "redhat"
    template        true
    state           "never"
  end
end
