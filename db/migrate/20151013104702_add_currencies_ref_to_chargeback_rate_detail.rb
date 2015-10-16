class AddCurrenciesRefToChargebackRateDetail < ActiveRecord::Migration
  def change
    add_reference :chargeback_rate_details, :chargeback_rate_detail_currency, :foreign_key => true
  end
end
