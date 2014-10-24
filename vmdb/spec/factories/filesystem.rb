FactoryGirl.define do
  factory :filesystem do
    sequence(:name)     { |n| "filesystem_#{seq_padded_for_sorting(n)}" }
  end
end
