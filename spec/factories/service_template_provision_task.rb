FactoryGirl.define do
  factory :service_template_provision_task do
    state        'pending'
    status       'Ok'
    request_type 'clone_to_service'
  end
end
