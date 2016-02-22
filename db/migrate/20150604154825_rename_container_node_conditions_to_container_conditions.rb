class RenameContainerNodeConditionsToContainerConditions < ActiveRecord::Migration
  class ContainerCondition < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    rename_table :container_node_conditions, :container_conditions
    rename_column :container_conditions, :container_node_id, :container_entity_id
    add_column :container_conditions, :container_entity_type, :string

    say_with_time("Adding container_entity_type 'ContainerNode' to all existing node conditions") do
      ContainerCondition.update_all(:container_entity_type => 'ContainerNode')
    end
  end

  def down
    say_with_time("remove all container group conditions to leave only container node conditions") do
      ContainerCondition.where(:container_entity_type => 'ContainerGroup').destroy_all
    end

    remove_column :container_conditions, :container_entity_type
    rename_column :container_conditions, :container_entity_id, :container_node_id
    rename_table :container_conditions, :container_node_conditions
  end
end
