FactoryGirl.define do
  factory :miq_ae_class do
    sequence(:name) { |n| "miq_ae_class_#{n}" }
  end
end
