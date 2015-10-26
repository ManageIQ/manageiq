class AddMeasureRefToChargebackRateDetail < ActiveRecord::Migration
  def change
    add_column :chargeback_rate_details, :chargeback_rate_detail_measure_id, :bigint
  end
end
