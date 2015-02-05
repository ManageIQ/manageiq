FactoryGirl.define do
  factory :condition do
    sequence(:name)  { |num| "condition_#{num}" }
    description      "Test Condition"
    modifier         "allow"
    towhat           "Vm"
    expression       MiqExpression.new(">=" => {"field" => "Vm-num_cpu", "value" => "2"})
  end
end
