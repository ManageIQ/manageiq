FactoryBot.define do
  factory :firmware_binary do
    sequence(:name)        { |n| "firmware_binary_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { 'Firmware Binary Description' }
    sequence(:version)     { 'v1.2.3' }

    trait :with_endpoints do
      after(:create) do |binary|
        binary.endpoints << FactoryBot.create(:endpoint, :resource => binary)
        binary.endpoints << FactoryBot.create(:endpoint, :resource => binary)
      end
    end
  end
end
