class AddOptionsToChargebackRateDetails < ActiveRecord::Migration[5.0]
  def change
    add_column :chargeback_rate_details, :options, :text
  end
end
