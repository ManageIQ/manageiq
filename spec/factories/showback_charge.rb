FactoryGirl.define do
  factory :showback_charge do
    showback_bucket
    showback_event
    fixed_cost 0
    variable_cost 0
  end
end
