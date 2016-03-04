class ChargebackRateDetailCurrencyNotNil < ActiveRecord::Migration
  # Migration in order to put a currency by default in rates that were added by a user before the addition of currencies
  class ChargebackRateDetail < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    currency = ChargebackRateDetailCurrency.find_by_name("Dollars")
    if currency
      currency_id = currency.id
    else
      cbc = ChargebackRateDetailCurrency.create(:code        => "USD",
                                                :name        => "Dollars",
                                                :full_name   => "United States Dollars",
                                                :symbol      => "$",
                                                :unicode_hex => "36"
                                               )
      currency_id = cbc.id
    end
    ChargebackRateDetail.where(:chargeback_rate_detail_currency_id => nil).update_all(:chargeback_rate_detail_currency_id => currency_id)
  end
end
