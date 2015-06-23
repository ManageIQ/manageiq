class CreateContainerGroupsContainerServices < ActiveRecord::Migration
  def change
    create_table :container_groups_container_services, :id => false do |t|
      t.bigint :container_service_id
      t.bigint :container_group_id
    end
  end
end
