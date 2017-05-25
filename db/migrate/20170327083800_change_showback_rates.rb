class ChangeShowbackRates < ActiveRecord::Migration[5.0]
  def up
    change_table :showback_rates do |t|
      t.change :fixed_cost,    :decimal, nil: true, default: nil
      t.change :variable_cost, :decimal, nil: true, default: nil
      t.string :calculation,  nil: false
      t.string :category, nil: false
      t.string :dimension, nil: false
      t.index :category
      t.index([:category, :dimension, :showback_tariff_id, :calculation], unique: true, name: 'unique_measure_type_for_rate')
    end
  end

  def down
    change_table :showback_rates do |t|
      t.remove_index :category
      t.remove_index(name: 'unique_measure_type_for_rate', unique: true )
      t.change :fixed_cost,    :money
      t.change :variable_cost, :money
      t.remove :calculation
      t.remove :category
      t.remove :dimension
    end
  end
end
