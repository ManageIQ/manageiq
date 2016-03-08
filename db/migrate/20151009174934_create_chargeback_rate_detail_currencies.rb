class CreateChargebackRateDetailCurrencies < ActiveRecord::Migration
  def change
    create_table :chargeback_rate_detail_currencies do |t|
      t.string :code
      t.string :name
      t.string :full_name
      t.string :symbol
      t.string :unicode_hex

      t.timestamps :null => false
    end
  end
end
