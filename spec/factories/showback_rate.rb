FactoryGirl.define do
  factory :showback_rate do
    variable_cost              { Random.rand(5..20) }
    fixed_cost                 { Random.rand(5..20) }
    calculation                "Duration"
    sequence(:category)        {|n| "CPU#{n}"}
    sequence(:dimension)       {|n| "max_CPU#{n}"}
    sequence(:concept)         { |n| "Concept #{n}" }
    showback_tariff
  end
end
