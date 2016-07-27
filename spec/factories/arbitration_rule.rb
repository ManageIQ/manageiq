FactoryGirl.define do
  factory :arbitration_rule do
    name 'arbitration rule'
    operation 'inject'
    expression 'EQUAL' => { 'field' => 'User-userid', 'value' => 'admin' }
  end
end
