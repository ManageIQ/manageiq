class AddImageRelationToContainer < ActiveRecord::Migration
  def up
    add_column :containers, :container_image_id, :bigint
    remove_column :containers, :image
    remove_column :containers, :image_ref
  end

  def down
    remove_column :containers, :container_image_id
    add_column :containers, :image, :string
    add_column :containers, :image_ref, :string
  end
end
