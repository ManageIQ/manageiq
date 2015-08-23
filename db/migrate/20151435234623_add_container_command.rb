class AddContainerCommand < ActiveRecord::Migration
  def change
    add_column :container_definitions, :command, :text
  end
end
