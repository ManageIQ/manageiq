class RemoveMiqQueueMd5 < ActiveRecord::Migration
  def up
    remove_column :miq_queue, :md5
  end

  def down
    add_column :miq_queue, :md5, :string
  end
end
