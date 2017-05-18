class AddContainerRelationship < ActiveRecord::Migration[4.2]
  def change
    add_column :containers, :container_definition_id, :bigint
  end
end
