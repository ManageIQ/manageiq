FactoryGirl.define do
  factory :service do
    sequence(:name) { |n| "service_#{seq_padded_for_sorting(n)}" }
  end
end
