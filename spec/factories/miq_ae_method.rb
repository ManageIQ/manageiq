FactoryBot.define do
  factory :miq_ae_method do
    sequence(:name) { |n| "miq_ae_method#{seq_padded_for_sorting(n)}" }
    language { "ruby" }
    location { "inline" }

    transient do
      params { {} }
    end

    before :create do |aemethod, evaluator|
      aemethod.ae_class ||= FactoryBot.create(:miq_ae_class) unless evaluator.class_id
    end

    after :create do |aemethod, evaluator|
      evaluator.params.each do |name, f|
        FactoryBot.create(:miq_ae_field,
                          :name          => name,
                          :datatype      => f['datatype'],
                          :aetype        => f['aetype'],
                          :method_id     => aemethod.id,
                          :default_value => f['default_value'].presence || '')
      end
    end
  end
end
