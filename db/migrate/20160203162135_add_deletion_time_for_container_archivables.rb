class AddDeletionTimeForContainerArchivables < ActiveRecord::Migration
  def change
    add_column :container_projects, :deleted_on, :datetime
    add_column :container_projects, :old_ems_id, :bigint
    add_column :container_groups, :deleted_on, :datetime
    add_column :container_groups, :old_ems_id, :bigint
    add_column :container_definitions, :deleted_on, :datetime
    add_column :containers, :deleted_on, :datetime
  end
end
