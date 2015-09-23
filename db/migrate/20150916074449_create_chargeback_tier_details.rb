class CreateChargebackTierDetails < ActiveRecord::Migration
  def change
    create_table :chargeback_tier_details do |t|
      t.string :description
      t.float :start
      t.float :end
      t.string :tier_rate
      t.bigint :chargeback_tier_id
      t.datetime :created_on
      t.string :updated_on
      t.string :datetime
    end
    add_index :chargeback_tier_details, ["chargeback_tier_id"], :name => "index_chargeback_tier_details_on_chargeback_tier"
  end
end
