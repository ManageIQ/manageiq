FactoryBot.define do
  factory :resource_group do
    sequence(:name) { |n| "rg_#{seq_padded_for_sorting(n)}" }
  end
end
