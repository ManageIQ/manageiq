class AddMeasureRefToChargebackRateDetail < ActiveRecord::Migration
  def change
    add_reference :chargeback_rate_details, :chargeback_rate_detail_measure,foreign_key: true
  end
end
