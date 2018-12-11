FactoryBot.define do
  factory :configuration_organization do
    sequence(:name) { |n| "configuration_organization#{seq_padded_for_sorting(n)}" }
  end
end
