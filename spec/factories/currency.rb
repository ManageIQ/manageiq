FactoryBot.define do
  factory :currency do
    code  { "EUR" }
    name { "Euro" }
    full_name { "Euro" }
    symbol { "€" }
    unicode_hex { "8364" }
  end
end
