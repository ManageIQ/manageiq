class AddConfigurationTemplateToResourceActions < ActiveRecord::Migration[5.0]
  def change
    add_column :resource_actions, :configuration_template_id,   :bigint
    add_column :resource_actions, :configuration_template_type, :string
  end
end
