FactoryGirl.define do
  factory :miq_ae_class do
    sequence(:name) { |n| "miq_ae_class_#{seq_padded_for_sorting(n)}" }

    trait :with_instances_and_methods do

      ignore do
        ae_fields {}
        ae_instances {}
        ae_methods {}
      end

      after :create do |aeclass, evaluator|

        aeclass.ae_fields << evaluator.ae_fields.collect do |name, f|
          FactoryGirl.build(:miq_ae_field, {:name => name}.merge(f))
        end

        evaluator.ae_instances.each do |name, values|
          FactoryGirl.create(:miq_ae_instance, :with_values,
                             :class_id => aeclass.id,
                             :name     => name,
                             'values'  => values)
        end

        evaluator.ae_methods.each do |name, aemethod|
          FactoryGirl.create(:miq_ae_method, :with_params,
                             {:class_id => aeclass.id,
                              :name     => name}.merge(aemethod))
        end
      end
    end
  end
end
