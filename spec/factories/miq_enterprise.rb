FactoryBot.define do
  factory :miq_enterprise do
    sequence(:name) { |n| "miq_enterprise_#{seq_padded_for_sorting(n)}" }
  end
end
