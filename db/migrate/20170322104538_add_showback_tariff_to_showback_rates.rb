class AddShowbackTariffToShowbackRates < ActiveRecord::Migration[5.0]
  def change
    change_table :showback_rates do |t|
      t.belongs_to :showback_tariff, :type => :bigint
    end
  end
end
