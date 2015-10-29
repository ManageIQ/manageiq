class AddCurrenciesRefToChargebackRateDetail < ActiveRecord::Migration
  def change
    add_column :chargeback_rate_details, :chargeback_rate_detail_currency_id, :bigint
  end
end
