class AddBlueprintToServiceTemplate < ActiveRecord::Migration[5.0]
  def change
    add_column :service_templates, :blueprint, :string
    add_index  :service_templates, :blueprint
  end
end
