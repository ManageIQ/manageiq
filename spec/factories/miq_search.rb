FactoryBot.define do
  factory :miq_search do
    sequence(:name)        { |n| "miq_search_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "MiqSearch #{seq_padded_for_sorting(n)}" }
    db          { "Vm" }
    search_type { "default" }

    filter { MiqExpression.new("CONTAINS" => {"tag" => "Vm.managed-environment", "value" => "prod"}) }
  end

  factory :miq_search_global, :parent => :miq_search do
    search_type { "global" }
  end

  factory :miq_search_user, :parent => :miq_search do
    search_type { "user" }
    search_key  { FactoryBot.create(:user).id }
  end
end
