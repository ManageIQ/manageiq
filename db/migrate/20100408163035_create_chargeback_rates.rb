class CreateChargebackRates < ActiveRecord::Migration
  def self.up
    create_table :chargeback_rates do |t|
      t.string      :guid, :limit => 36
      t.string      :description
      t.string      :rate_type
      t.timestamp   :created_on
      t.timestamp   :updated_on
    end

    create_table :chargeback_rate_details do |t|
      t.boolean     :enabled, :default => true
      t.string      :description
      t.string      :group
      t.string      :rate_type
      t.string      :metric
      t.string      :rate
      t.string      :per_time
      t.string      :per_unit
      t.string      :friendly_rate
      t.integer     :chargeback_rate_id
      t.timestamp   :created_on
      t.timestamp   :updated_on
    end
  end

  def self.down
    drop_table :chargeback_rates
    drop_table :chargeback_rate_details
  end
end
