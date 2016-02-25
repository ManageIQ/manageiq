class ChargebackRateDetailCurrencyNotNil < ActiveRecord::Migration
  # Migration in order to put a currency by default in rates that were seeded or added by a user before the addition of currencies
  class ChargebackRateDetail < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    ChargebackRateDetail.where(:chargeback_rate_detail_currency_id => nil).update_all(:chargeback_rate_detail_currency_id => 0)
  end
end
