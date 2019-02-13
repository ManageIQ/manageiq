FactoryBot.define do
  factory :miq_policy_set do
    description { "Test Policy Set" }
  end

  factory :miq_policy_set_read_only, :parent => :miq_policy_set do
    read_only { true }
  end
end
