class AddOpenedToConsoles < ActiveRecord::Migration[5.0]
  def change
    add_column :consoles, :opened, :boolean, :default => false
  end
end
