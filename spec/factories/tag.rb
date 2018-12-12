FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "/namespace/cat/tag_#{seq_padded_for_sorting(n)}" }
  end
end
