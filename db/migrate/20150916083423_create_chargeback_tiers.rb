class CreateChargebackTiers < ActiveRecord::Migration
  def change
    create_table :chargeback_tiers do |t|
      t.string :guid,          :limit => 36
      t.string :name
      t.string :description
      t.float :rate_below
      t.float :rate_above
      t.datetime :created_on
      t.string :updated_on
      t.string :datetime
    end
  end
end
