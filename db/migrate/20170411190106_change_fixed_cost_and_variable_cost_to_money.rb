class ChangeFixedCostAndVariableCostToMoney < ActiveRecord::Migration[5.0]
  def up
    change_table :showback_rates do |t|
      t.remove   :fixed_cost
      t.remove   :variable_cost
      t.monetize :fixed_rate
      t.monetize :variable_rate
    end
    change_table :showback_charges do |t|
      t.remove   :fixed_cost
      t.remove   :variable_cost
      t.monetize :fixed_cost
      t.monetize :variable_cost
    end
  end

  def down
    remove_monetize :showback_rates, :variable_rate
    remove_monetize :showback_rates, :fixed_rate
    remove_monetize :showback_charges, :variable_cost
    remove_monetize :showback_charges, :fixed_cost
    add_column :showback_rates,   :variable_cost, :decimal, :allow_nil  => true, :default => nil
    add_column :showback_rates,   :fixed_cost,    :decimal, :allow_nil  => true, :default => nil
    add_column :showback_charges, :variable_cost, :decimal, :allow_nil  => true, :default => nil
    add_column :showback_charges, :fixed_cost,    :decimal, :allow_nil  => true, :default => nil
  end
end
