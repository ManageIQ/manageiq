FactoryBot.define do
  factory :miq_ae_instance do
    sequence(:name) { |n| "miq_ae_instance_#{seq_padded_for_sorting(n)}" }

    transient do
      values { {} }
    end

    before :create do |aeinstance, evaluator|
      aeinstance.ae_class ||= FactoryBot.create(:miq_ae_class) unless evaluator.class_id
    end

    after :create do |aeinstance, evaluator|
      unless evaluator.values.empty?
        aeinstance.ae_values << aeinstance.ae_class.ae_fields.collect do |field|
          next unless evaluator.values.key?(field.name)
          FactoryBot.build(:miq_ae_value, {:field_id => field.id}.merge(evaluator.values[field.name]))
        end
      end
    end
  end
end
