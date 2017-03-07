FactoryGirl.define do
  factory :showback_configuration do

    sequence(:name)          { |s| "name #{s}" }
    sequence(:description)   { |s| "Description #{s}" }
    measure                  'Integer'
    types                    ["cpu_usage_rate_average", "cpu_usagemhz_rate_average"]

  end
end
