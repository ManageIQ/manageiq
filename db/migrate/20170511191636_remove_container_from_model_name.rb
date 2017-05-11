class RemoveContainerFromModelName < ActiveRecord::Migration[5.0]
  def change
    rename_table :container_label_tag_mappings, :label_tag_mappings
  end
end
