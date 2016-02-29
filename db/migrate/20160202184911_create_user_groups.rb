class CreateUserGroups < ActiveRecord::Migration
  # TODO: Need a real migration to reassociate the data properly
  # TODO: group_id in miq_sets will have to be migrated as well, I believe
  def change
    create_table :user_groups do |t|
      t.timestamps null: false
      t.string :guid, limit: 36
      t.string :description
    end

    create_table :user_groups_users, :id => false do |t|
      t.references :user_group, :null => false
      t.references :user, :null => false
    end
    add_index(:user_groups_users, [:user_group_id, :user_id], :unique => true)

    create_table :miq_groups_user_groups, :id => false do |t|
      t.references :user_group, :null => false
      t.references :miq_group, :null => false
    end
    add_index(:miq_groups_user_groups, [:user_group_id, :miq_group_id], :unique => true)

    drop_table :miq_groups_users

    remove_column :miq_groups, :guid
    remove_column :miq_groups, :description

    associated_tables = %i(vms
                           miq_reports
                           miq_report_results
                           miq_widget_contents)

    associated_tables.each do |table|
      remove_column table, :miq_group_id
      add_column    table, :user_group_id, :integer
      add_index     table, :user_group_id unless table == :miq_widget_contents
    end
  end
end
