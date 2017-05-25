FactoryGirl.define do
  factory :showback_measure_type do

    sequence(:name)          { |s| "name #{s}" }
    sequence(:description)   { |s| "Description #{s}" }
    measure                  'CPU'
    types                    ["average"]

  end
end
