FactoryBot.define do
  factory :endpoint do
    port { 443 }
    hostname { "example.com" }
  end
end
