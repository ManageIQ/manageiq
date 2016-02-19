class AddPersistentVolumesToContainerVolumes < ActiveRecord::Migration
  class ContainerVolume < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    add_column :container_volumes, :ems_ref, :string
    add_column :container_volumes, :creation_timestamp, :timestamp
    add_column :container_volumes, :resource_version, :string
    add_column :container_volumes, :capacity, :string
    add_column :container_volumes, :access_modes, :string
    add_column :container_volumes, :reclaim_policy, :string
    add_column :container_volumes, :status_phase, :string
    add_column :container_volumes, :status_message, :string
    add_column :container_volumes, :status_reason, :string
    add_column :container_volumes, :parent_type, :string
    say_with_time("Update ContainerVolume parent_type to ContainerGroup") do
      ContainerVolume.update_all(:parent_type => "ContainerGroup")
    end
    rename_column :container_volumes, :container_group_id, :parent_id
  end

  def down
    remove_column :container_volumes, :ems_ref, :string
    remove_column :container_volumes, :creation_timestamp, :timestamp
    remove_column :container_volumes, :resource_version, :string
    remove_column :container_volumes, :capacity, :string
    remove_column :container_volumes, :access_modes, :string
    remove_column :container_volumes, :reclaim_policy, :string
    remove_column :container_volumes, :status_phase, :string
    remove_column :container_volumes, :status_message, :string
    remove_column :container_volumes, :status_reason, :string
    say_with_time("Deleting ContainerVolumes not belonging to ContainerGroups") do
      ContainerVolume.where("parent_type != 'ContainerGroup'").delete_all
    end
    remove_column :container_volumes, :parent_type, :string
    rename_column :container_volumes, :parent_id, :container_group_id
  end
end
