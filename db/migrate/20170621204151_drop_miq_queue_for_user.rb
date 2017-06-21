class DropMiqQueueForUser < ActiveRecord::Migration[5.0]
  def up
    remove_column :miq_queue, :for_user
    remove_column :miq_queue, :for_user_id
  end

  def down
    add_column :miq_queue, :for_user,    :string
    add_column :miq_queue, :for_user_id, :bigint
  end
end
