FactoryBot.define do
  factory :container_route do
    sequence(:name) { |n| "container_route_#{seq_padded_for_sorting(n)}" }
  end
end
