FactoryBot.define do
  factory :chargeback_tier do
    start { 0 }
    finish { Float::INFINITY }
    fixed_rate { 0.0 }
    variable_rate { 0.0 }

    trait :first_of_three do
      start { 0.0 }
      finish { 20.0 }
      fixed_rate { 0.1 }
      variable_rate { 0.2 }
    end

    trait :second_of_three do
      start { 20.0 }
      finish { 40.0 }
      fixed_rate { 0.3 }
      variable_rate { 0.4 }
    end

    trait :third_of_three do
      start { 40.0 }
      finish { Float::INFINITY }
      fixed_rate { 0.5 }
      variable_rate { 0.6 }
    end
  end

  factory :chargeback_tier_first_of_three, :traits => [:first_of_three], :parent => :chargeback_tier
  factory :chargeback_tier_second_of_three, :traits => [:second_of_three], :parent => :chargeback_tier
  factory :chargeback_tier_third_of_three, :traits => [:third_of_three], :parent => :chargeback_tier
end
