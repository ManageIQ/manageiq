FactoryGirl.define do
  factory :miq_ae_instance do
    sequence(:name) { |n| "miq_ae_instance_#{n}" }
  end
end
