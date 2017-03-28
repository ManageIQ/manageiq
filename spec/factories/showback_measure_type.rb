FactoryGirl.define do
  factory :showback_measure_type do

    category                 'VM'
    sequence(:description)   { |s| "Description #{s}" }
    measure                  'CPU'
    dimensions               ["average"]

  end
end
