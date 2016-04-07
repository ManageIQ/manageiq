FactoryGirl.define do
  factory :chargeback_tier do
    start 0
    finish Float::INFINITY
    fixed_rate 0.0
    variable_rate 0.0
  end
end
