class AddLongDescriptionToServiceTemplates < ActiveRecord::Migration
  def change
    add_column :service_templates, :long_description, :text
  end
end
