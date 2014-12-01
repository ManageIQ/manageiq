FactoryGirl.define do
  factory :miq_ae_instance do
    sequence(:name) { |n| "miq_ae_instance_#{seq_padded_for_sorting(n)}" }

    trait :with_values do
      ignore do
        values {}
      end

      after :create do |aeinstance, evaluator|
        aeinstance.ae_values << aeinstance.ae_class.ae_fields.collect do |field|
          next unless evaluator.values.key?(field.name)
          FactoryGirl.build(:miq_ae_value, {:field_id => field.id}.merge(evaluator.values[field.name]))
        end
      end

    end
  end
end
