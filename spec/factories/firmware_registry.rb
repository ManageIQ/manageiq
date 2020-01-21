FactoryBot.define do
  factory :firmware_registry do
    sequence(:name) { |n| "firmware_registry_#{seq_padded_for_sorting(n)}" }
    endpoint { FactoryBot.create(:endpoint) }
    authentication { FactoryBot.create(:authentication) }
  end

  factory :firmware_registry_rest_api_depot,
          :parent => :firmware_registry,
          :class  => 'FirmwareRegistry::RestApiDepot'
end
