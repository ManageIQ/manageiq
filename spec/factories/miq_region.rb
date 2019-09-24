FactoryBot.define do
  region_remote = MiqRegion.my_region_number

  factory :miq_region do
    sequence(:region) { |region| region == region_remote ? region + 1 : region }
  end
end
