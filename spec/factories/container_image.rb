FactoryBot.define do
  factory :container_image do
    sequence(:name) { |n| "container_image_#{seq_padded_for_sorting(n)}" }
  end
end
