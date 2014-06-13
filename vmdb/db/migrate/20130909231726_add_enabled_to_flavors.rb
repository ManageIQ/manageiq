class AddEnabledToFlavors < ActiveRecord::Migration
  def change
    add_column :flavors, :enabled, :boolean
  end
end
