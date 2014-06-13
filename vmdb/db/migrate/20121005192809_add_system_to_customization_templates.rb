class AddSystemToCustomizationTemplates < ActiveRecord::Migration
  def change
    add_column :customization_templates, :system, :boolean
  end
end
