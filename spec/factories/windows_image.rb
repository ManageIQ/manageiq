FactoryBot.define do
  factory :windows_image do
    sequence(:name)         { |n| "windows_image_#{seq_padded_for_sorting(n)}" }
    sequence(:description)  { |n| "windows_desc_#{seq_padded_for_sorting(n)}"  }
  end
end
