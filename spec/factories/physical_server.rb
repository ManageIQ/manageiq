FactoryBot.define do
  factory :physical_server do
    vendor { "lenovo" }

    trait :with_asset_detail do
      after :create do |server|
        server.asset_detail = FactoryBot.create(:asset_detail)
      end
    end
  end
end
