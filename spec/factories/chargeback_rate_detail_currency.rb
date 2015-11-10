FactoryGirl.define do
  factory :chargeback_rate_detail_currency do
    code  "EUR"
  end

  factory :chargeback_rate_detail_currency_EUR, :parent => :chargeback_rate_detail_currency do
    name "Euro"
    full_name "Euro"
    symbol "€"
    unicode_hex "8364"
  end
end
