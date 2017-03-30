FactoryGirl.define do
  factory :showback_event do
    sequence(:id_obj)         { |n| 100_000 + n }
    type_obj                  'VmOrTemplate'
    start_time                4.hours.ago
    end_time                  1.hour.ago
    context                   {}
  end
end
