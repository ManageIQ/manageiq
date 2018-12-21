FactoryBot.define do
  factory :resource_pool do
    sequence(:name) { |n| "rp_#{seq_padded_for_sorting(n)}" }
  end
end
