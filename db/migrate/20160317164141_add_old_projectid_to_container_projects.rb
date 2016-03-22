class AddOldProjectidToContainerProjects < ActiveRecord::Migration[5.0]
  def change
    add_column :container_groups, :old_container_project_id, :bigint
  end
end
