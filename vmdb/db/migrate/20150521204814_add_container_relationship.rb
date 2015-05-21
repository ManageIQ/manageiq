class AddContainerRelationship < ActiveRecord::Migration
  def change
    add_column :containers, :container_definition_id, :bigint
  end
end
