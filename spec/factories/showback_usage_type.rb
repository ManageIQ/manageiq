FactoryGirl.define do
  factory :showback_usage_type do
    category                 'VmOrTemplate'
    sequence(:description)   { |s| "Description #{s}" }
    measure                  'CPU'
    dimensions               ["average"]
  end
end
