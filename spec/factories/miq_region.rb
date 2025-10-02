FactoryBot.define do
  factory :miq_region do
    sequence(:region) do |region|
      region_remote = MiqRegion.my_region_number
      region == region_remote ? region + 1 : region
    end
  end
end
