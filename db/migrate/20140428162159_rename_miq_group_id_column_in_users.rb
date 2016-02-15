class RenameMiqGroupIdColumnInUsers < ActiveRecord::Migration
  def up
    remove_index  :users, :miq_group_id
    rename_column :users, :miq_group_id, :current_group_id
    add_index     :users, :current_group_id
  end

  def down
    remove_index  :users, :current_group_id
    rename_column :users, :current_group_id, :miq_group_id
    add_index     :users, :miq_group_id
  end
end
