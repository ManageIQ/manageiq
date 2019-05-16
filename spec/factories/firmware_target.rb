FactoryBot.define do
  factory :firmware_target do
    sequence(:manufacturer)  { |n| "manufacturer_#{seq_padded_for_sorting(n)}" }
    sequence(:model)         { |n| "model_#{seq_padded_for_sorting(n)}" }
  end
end
