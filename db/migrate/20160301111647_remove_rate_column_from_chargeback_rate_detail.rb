class RemoveRateColumnFromChargebackRateDetail < ActiveRecord::Migration[4.2]
  def change
    remove_column :chargeback_rate_details, :rate, :string
  end
end
