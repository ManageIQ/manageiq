FactoryGirl.define do
  factory :service do
    sequence(:name) { |n| "service_#{seq_padded_for_sorting(n)}" }
  end

  factory :service_orchestration, :class => :ServiceOrchestration, :parent => :service do
  end
end
