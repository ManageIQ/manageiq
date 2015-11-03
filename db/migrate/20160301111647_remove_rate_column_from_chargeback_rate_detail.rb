class RemoveRateColumnFromChargebackRateDetail < ActiveRecord::Migration
  def change
    remove_column :chargeback_rate_details, :rate, :string
  end
end
