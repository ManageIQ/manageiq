class AddChargebackTierIdToChargebackRateDetails < ActiveRecord::Migration
  def change
    add_column :chargeback_rate_details, :chargeback_tier, :bigint
  end
end
