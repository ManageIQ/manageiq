FactoryGirl.define do
  factory :showback_rate do
    variable_rate        { Money.new(rand(5..20), 'USD') }
    fixed_rate           { Money.new(rand(5..20), 'USD') }
    calculation                "Duration"
    sequence(:category)        { |n| "CPU#{n}" }
    sequence(:dimension)       { |n| "max_CPU#{n}" }
    sequence(:concept)         { |n| "Concept #{n}" }
    showback_price_plan
  end
end
