class RemoveMiqUserRoleFromMiqGroups < ActiveRecord::Migration[5.0]
  def change
    remove_column :miq_groups, :miq_user_role_id, :bigint
  end
end
