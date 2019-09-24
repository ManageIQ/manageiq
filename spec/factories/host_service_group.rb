FactoryBot.define do
  factory :host_service_group do
    sequence(:name) { |n| "host_service_group_#{seq_padded_for_sorting(n)}" }
  end
end
