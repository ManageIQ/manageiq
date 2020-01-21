FactoryBot.define do
  factory :pxe_image_type do
    sequence(:name) { |n| "pxe_image_type_#{seq_padded_for_sorting(n)}" }
  end
end
