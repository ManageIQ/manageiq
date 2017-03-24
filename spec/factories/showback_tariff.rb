FactoryGirl.define do
  factory :showback_tariff do
    sequence(:name)           { |n| "factory_tariff_#{seq_padded_for_sorting(n)}" }
    sequence(:description)    { |n| "tariff_description_#{seq_padded_for_sorting(n)}" }
  end
end
