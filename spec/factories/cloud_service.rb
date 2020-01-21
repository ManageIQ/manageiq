FactoryBot.define do
  factory :cloud_service do
    sequence(:executable_name) { |n| "cloud_service_#{seq_padded_for_sorting(n)}" }
    scheduling_disabled { false }
  end
end
