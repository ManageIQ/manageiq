class ChargebackRateDetailCurrencyNotNil < ActiveRecord::Migration
  # Migration in order to put a currency by default in rates that were added by a user before the addition of currencies
  class ChargebackRateDetail < ActiveRecord::Base; end

  class ChargebackRateDetailCurrency < ActiveRecord::Base; end

  def up
    chargeback_rate_details = ChargebackRateDetail.where(:chargeback_rate_detail_currency_id => nil)
    if !chargeback_rate_details.count.zero?
      currency = ChargebackRateDetailCurrency.find_by(:name => "Dollars") ||
                 ChargebackRateDetailCurrency.create(:code        => "USD",
                                                     :name        => "Dollars",
                                                     :full_name   => "United States Dollars",
                                                     :symbol      => "$",
                                                     :unicode_hex => "36"
      )
      chargeback_rate_details.update_all(:chargeback_rate_detail_currency_id => currency.id)
    end
  end
end
