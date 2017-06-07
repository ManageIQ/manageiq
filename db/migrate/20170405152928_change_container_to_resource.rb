class ChangeContainerToResource < ActiveRecord::Migration[5.0]
  def change
    rename_table :container_label_tag_mappings, :resource_label_tag_mappings
  end
end
