class AddOriginalBlueprintId < ActiveRecord::Migration[5.0]
  def change
    add_column :blueprints, :original_blueprint_id, :bigint
    add_column :blueprints, :active_version, :boolean
  end
end
