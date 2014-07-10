FactoryGirl.define do
  factory :miq_ae_method do
    sequence(:name) { |n| "miq_ae_method#{n}" }

    trait :with_params do
      ignore do
        params {}
      end

      after :create do |aemethod, evaluator|
        evaluator.params.each do |name, f|
          FactoryGirl.create(:miq_ae_field,
                             :name          => name,
                             :datatype      => f['datatype'],
                             :aetype        => f['aetype'],
                             :method_id     => aemethod.id,
                             :default_value => f['default_value'].blank? ? '' : f['default_value'])
        end
      end
    end
  end
end
