class RemoveUiTasksAndUiTaskSets < ActiveRecord::Migration
  class MiqSet < ActiveRecord::Base; end

  class Relationship < ActiveRecord::Base; end

  def up
    remove_index :ui_tasks, [:area, :typ, :task]
    drop_table   :ui_tasks

    remove_index  :users, :ui_task_set_id
    remove_column :users, :ui_task_set_id

    remove_index  :miq_groups, :ui_task_set_id
    remove_column :miq_groups, :ui_task_set_id

    say_with_time "Removing UiTaskSets" do
      MiqSet.where(:set_type => "UiTaskSet").delete_all
      Relationship.where(:resource_type => ["UiTask", "UiTaskSet"]).delete_all
    end
  end

  def down
    create_table :ui_tasks do |t|
      t.string   :name
      t.string   :area
      t.string   :typ
      t.string   :task
      t.datetime :created_on
      t.datetime :updated_on
    end

    add_index :ui_tasks, [:area, :typ, :task]

    add_column :users, :ui_task_set_id, :bigint
    add_index  :users, :ui_task_set_id

    add_column :miq_groups, :ui_task_set_id, :bigint
    add_index  :miq_groups, :ui_task_set_id
  end
end
