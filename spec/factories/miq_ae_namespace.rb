FactoryGirl.define do
  factory :miq_ae_namespace do
    sequence(:name) { |n| "miq_ae_namespace_#{seq_padded_for_sorting(n)}" }
  end
end
