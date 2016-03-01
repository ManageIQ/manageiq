class CreateUserGroups < ActiveRecord::Migration[5.0]
  def change
    # TODO The primary key here should be bigint
    create_table :user_groups do |t|
      t.bigint :miq_group_id

      t.timestamps
    end

    create_table :user_groups_users, id: false do |t|
      t.bigint :user_id
      t.bigint :user_group_id
    end

    add_column :miq_groups, :user_group_id, :bigint

    add_index :user_groups_users, :user_id

    drop_table :miq_groups_users
  end
end
