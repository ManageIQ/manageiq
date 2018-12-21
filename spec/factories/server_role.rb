FactoryBot.define do
  factory :server_role do
    sequence(:name) { |i| "role#{i}"}
  end
end
