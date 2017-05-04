class AddContainerCommand < ActiveRecord::Migration[4.2]
  def change
    add_column :container_definitions, :command, :text
  end
end
