class AddServiceSystemdDeps < ActiveRecord::Migration
  def change
    add_column :system_services, :dependencies, :text
  end
end
