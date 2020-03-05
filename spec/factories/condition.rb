FactoryBot.define do
  factory :condition do
    sequence(:name)        { |num| "condition_#{seq_padded_for_sorting(num)}" }
    sequence(:description) { |num| "Condition #{seq_padded_for_sorting(num)}" }
    target_class_name          { "Vm" }
    expression             { MiqExpression.new(">=" => {"field" => "Vm-num_cpu", "value" => "2"}) }
  end
end
