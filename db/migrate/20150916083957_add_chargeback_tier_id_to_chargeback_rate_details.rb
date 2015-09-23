class AddChargebackTierIdToChargebackRateDetails < ActiveRecord::Migration
  def change
    add_column :chargeback_rate_details, :chargeback_tier_id, :bigint
  end
end
