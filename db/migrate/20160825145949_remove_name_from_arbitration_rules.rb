class RemoveNameFromArbitrationRules < ActiveRecord::Migration[5.0]
  def up
    remove_column :arbitration_rules, :name
  end

  def down
    add_column :arbitration_rules, :name, :string
  end
end
