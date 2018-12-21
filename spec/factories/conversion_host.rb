FactoryBot.define do
  factory :conversion_host do
    sequence(:name) { |n| "conversion_host_#{seq_padded_for_sorting(n)}" }
  end
end
