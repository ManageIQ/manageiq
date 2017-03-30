
DATA = { "CPU" => {"average" => 0} }.to_json

FactoryGirl.define do
  factory :showback_event do
    data                      DATA
    sequence(:id_obj)         { |n| 100_000 + n }
    type_obj                  'VM'
    start_time                4.hours.ago
    end_time                  1.hour.ago
    context                   {}
  end
end
