class ChargebackRateDetailCurrencyNotNil < ActiveRecord::Migration
  # Migration in order to put a currency by default in rates that were seeded or added by a user before the addition of currencies
  def up
    ChargebackRateDetail.where(:chargeback_rate_detail_currency_id => nil).update_all(:chargeback_rate_detail_currency_id => ChargebackRateDetailCurrency.first.id)
  end
end
