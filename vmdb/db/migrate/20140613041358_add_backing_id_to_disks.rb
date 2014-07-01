class AddBackingIdToDisks < ActiveRecord::Migration
  def up
    change_table :disks do |t|
      t.integer :backing_id, :limit => 8
      t.string  :backing_type
    end
  end

  def down
    change_table :disks do |t|
      t.remove :backing_id
      t.remove :backing_type
    end
  end
end
