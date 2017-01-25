class AddChargeableFieldToChargebackRateDetail < ActiveRecord::Migration[5.0]
  def change
    add_column :chargeback_rate_details, :chargeable_field_id, :bigint
  end
end
