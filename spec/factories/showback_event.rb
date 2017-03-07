
DATA = { 3.hours.ago => {"cpu_usage_rate_average" => 2} }.to_json

FactoryGirl.define do
  factory :showback_event do
    data                      DATA
    sequence(:id_obj)         { |n| 100_000 + n }
    type_obj                  'VM'
    start_time                4.hours.ago
    end_time                  1.hour.ago
    showback_configuration
  end
end
