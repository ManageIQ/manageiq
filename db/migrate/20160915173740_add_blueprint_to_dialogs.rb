class AddBlueprintToDialogs < ActiveRecord::Migration[5.0]
  def change
    add_column :dialogs, :blueprint_id, :bigint
  end
end
