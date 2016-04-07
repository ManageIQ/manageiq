class CreateChargebackTiers < ActiveRecord::Migration
  def change
    create_table :chargeback_tiers do |t|
      t.bigint :chargeback_rate_detail_id
      t.float :start
      t.float :finish
      t.float :fixed_rate
      t.float :variable_rate

      t.timestamp :null => false
    end
  end
end
