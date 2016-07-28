class AddBlueprintIdToServiceTemplates < ActiveRecord::Migration[5.0]
  def change
    add_column :service_templates, :blueprint_id, :bigint
  end
end
