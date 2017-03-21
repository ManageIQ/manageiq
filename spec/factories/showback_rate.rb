FactoryGirl.define do
  factory :showback_rate do
    sequence(:variable_cost)   { |n| BigDecimal.new(n) }
    fixed_cost                 BigDecimal.new("4.05")
    date                       DateTime.current
    sequence(:concept)         { |n| "Concept #{n}" }
  end
end
