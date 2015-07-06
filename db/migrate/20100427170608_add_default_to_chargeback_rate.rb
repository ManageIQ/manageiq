class AddDefaultToChargebackRate < ActiveRecord::Migration
  def self.up
    add_column    :chargeback_rates, :default,  :boolean, :default => false
    rename_column :chargeback_rate_details, :rate_type, :source
  end

  def self.down
    remove_column :chargeback_rates, :default
    rename_column :chargeback_rate_details, :source, :rate_type
  end
end
