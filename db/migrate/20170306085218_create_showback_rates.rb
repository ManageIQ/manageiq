class CreateShowbackRates < ActiveRecord::Migration[5.0]
  def up
    create_table :showback_rates do |t|
      t.decimal :fixed_cost,    :null => false, :precision => 16, :scale     => 2
      t.decimal :variable_cost, :null => false, :default   => 0,  :precision => 16, :scale => 2
      t.datetime :date
      t.string :concept

      t.timestamps
    end
  end

  def down
    drop_table :showback_rates
  end
end
