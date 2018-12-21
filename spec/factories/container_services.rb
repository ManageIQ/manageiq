FactoryBot.define do
  factory :container_service do
    sequence(:name) { |n| "container_service_#{seq_padded_for_sorting(n)}" }
  end
end
