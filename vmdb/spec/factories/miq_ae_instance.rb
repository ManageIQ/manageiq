FactoryGirl.define do
  factory :miq_ae_instance do
    sequence(:name) { |n| "miq_ae_instance_#{seq_padded_for_sorting(n)}" }

    trait :with_values do
      ignore do
        values {}
      end

      after :create do |aeinstance, evaluator|
        aeinstance.ae_class.ae_fields.each do |field|
          next unless evaluator.values.key?(field.name)
          FactoryGirl.create(:miq_ae_value, {:instance_id => aeinstance.id,
                                             :field_id    => field.id}.merge(evaluator.values[field.name]))
        end
      end

    end
  end
end
