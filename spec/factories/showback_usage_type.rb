FactoryGirl.define do
  factory :showback_usage_type do
    category                 'Vm'
    sequence(:description)   { |s| "Description #{s}" }
    measure                  'CPU'
    dimensions               ["average"]
  end
end
