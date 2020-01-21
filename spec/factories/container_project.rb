FactoryBot.define do
  factory :container_project do
    sequence(:name) { |n| "container_project_#{seq_padded_for_sorting(n)}" }
  end
end
