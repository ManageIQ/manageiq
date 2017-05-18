class AddImageIdToContainers < ActiveRecord::Migration[4.2]
  def up
    add_column    :containers, :image_ref, :string
  end

  def down
    remove_column :containers, :image_ref
  end
end
