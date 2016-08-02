class AddBootableToDisks < ActiveRecord::Migration[5.0]
  def change
    add_column :disks, :bootable, :boolean
  end
end
