FactoryGirl.define do
  factory :filesystem do
    sequence(:name)     { |n| "filesystem_#{n}" }
  end
end
