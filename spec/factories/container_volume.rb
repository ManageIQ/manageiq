FactoryBot.define do
  factory :container_volume do
    sequence(:name) { |n| "container_volume_#{seq_padded_for_sorting(n)}" }
  end
end
