FactoryBot.define do
  factory :persistent_volume do
    sequence(:name) { |n| "persistent_volume_#{seq_padded_for_sorting(n)}" }
  end
end
