class CreateChargebackRateDetailMeasure < ActiveRecord::Migration
  def change
    create_table :chargeback_rate_detail_measures do |t|
      t.string :name
      t.string :units
      t.string :units_display
      t.integer :step

      t.timestamps :null => false
    end
  end
end
