FactoryBot.define do
  factory :persistent_volume_claim do
    sequence(:name) { |n| "persistent_volume_claim_#{seq_padded_for_sorting(n)}" }
  end
end
