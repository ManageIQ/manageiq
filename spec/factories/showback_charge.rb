FactoryGirl.define do
  factory :showback_charge do
    showback_bucket
    showback_event
    fixed_cost nil
    variable_cost nil
  end
end
