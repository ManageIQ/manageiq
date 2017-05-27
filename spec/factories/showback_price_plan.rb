FactoryGirl.define do
  factory :showback_price_plan do
    sequence(:name)           { |n| "factory__price_plan_#{seq_padded_for_sorting(n)}" }
    sequence(:description)    { |n| "price_plan_description_#{seq_padded_for_sorting(n)}" }
    association :resource, :factory => :miq_enterprise, :strategy => :build_stubbed
  end
end
