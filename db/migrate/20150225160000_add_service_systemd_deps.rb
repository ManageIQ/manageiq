class AddServiceSystemdDeps < ActiveRecord::Migration[4.2]
  def change
    add_column :system_services, :dependencies, :text
  end
end
