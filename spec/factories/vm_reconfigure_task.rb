FactoryGirl.define do
  factory :vm_reconfigure_task do
    status "Ok"
    state  "active"
    request_type "vm_reconfigure"
  end
end
