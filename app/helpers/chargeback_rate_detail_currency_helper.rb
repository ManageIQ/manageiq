module ChargebackRateDetailCurrencyHelper
  def currencies_for_select
    # Return an array with the codes of the currencies
    currency_id = []
    currency_code = []
    ChargebackRateDetailCurrency.all.each do |i|
      currency_code << i.code
      currency_id << i.id
    end
    Hash[currency_code.zip(currency_id)]
  end
end
