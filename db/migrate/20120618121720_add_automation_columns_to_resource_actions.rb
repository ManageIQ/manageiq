class AddAutomationColumnsToResourceActions < ActiveRecord::Migration
  def change
    add_column :resource_actions, :ae_namespace,  :string
    add_column :resource_actions, :ae_class,      :string
    add_column :resource_actions, :ae_instance,   :string
    add_column :resource_actions, :ae_message,    :string
    add_column :resource_actions, :ae_attributes, :text
  end
end
