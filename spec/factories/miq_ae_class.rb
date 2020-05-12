FactoryBot.define do
  factory :miq_ae_class do
    sequence(:name) { |n| "miq_ae_class_#{seq_padded_for_sorting(n)}" }

    trait :with_instances_and_methods do
      transient do
        ae_fields { {} }
        ae_instances { {} }
        ae_methods { {} }
      end

      after :create do |aeclass, evaluator|
        aeclass.ae_fields << evaluator.ae_fields.collect do |name, f|
          FactoryBot.build(:miq_ae_field, {:name => name}.merge(f))
        end

        evaluator.ae_instances.each do |name, values|
          FactoryBot.create(:miq_ae_instance,
                             :class_id => aeclass.id,
                             :name     => name,
                             'values'  => values)
        end

        evaluator.ae_methods.each do |name, aemethod|
          FactoryBot.create(:miq_ae_method,
                             {:class_id => aeclass.id,
                              :name     => name}.merge(aemethod))
        end
      end
    end

    before(:create) do |aeclass|
      aeclass.ae_namespace ||= FactoryBot.create(:miq_ae_namespace, :parent => aeclass.domain) unless aeclass.namespace_id
    end
  end
end
