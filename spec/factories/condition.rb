FactoryGirl.define do
  factory :condition do
    sequence(:name)        { |num| "condition_#{seq_padded_for_sorting(num)}" }
    sequence(:description) { |num| "Condition #{seq_padded_for_sorting(num)}" }
    towhat                 "Vm"
    expression             { MiqExpression.new(">=" => {"field" => "Vm-num_cpu", "value" => "2"}) }
  end
end
