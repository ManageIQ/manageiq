FactoryBot.define do
  factory :generic_object_definition do
    sequence(:name) { |n| "generic_object_definition_#{seq_padded_for_sorting(n)}" }

    trait :with_methods_attributes_associations do
      properties do
        {
          :methods      => %w(add_vms remove_vms),
          :attributes   => { 'powered_on' => 'boolean', 'widget' => 'string' },
          :associations => { 'vms' => 'Vm', 'services' => 'Service' }
        }
      end
    end
  end
end
