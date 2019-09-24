FactoryBot.define do
  factory :container_image_registry do
    sequence(:name) { |n| "image_registry_#{seq_padded_for_sorting(n)}" }
  end
end
