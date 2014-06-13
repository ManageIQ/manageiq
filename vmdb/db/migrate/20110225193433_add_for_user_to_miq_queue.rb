class AddForUserToMiqQueue < ActiveRecord::Migration
  def self.up
    add_column :miq_queue, :for_user,    :string
    add_column :miq_queue, :for_user_id, :bigint
  end

  def self.down
    remove_column :miq_queue, :for_user
    remove_column :miq_queue, :for_user_id
  end
end
