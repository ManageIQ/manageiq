FactoryGirl.define do
  factory :showback_event do
    resource_type             'VmOrTemplate'
    resource_id               { FactoryGirl.create(:vm_or_template).id }
    start_time                4.hours.ago
    end_time                  1.hour.ago
    context                   {}
  end
end
