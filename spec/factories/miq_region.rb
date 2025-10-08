FactoryBot.define do
  factory :miq_region do
    sequence(:region) do |region|
      region == ApplicationRecord.region_number_from_sequence ? region + 1 : region
    end
  end
end
