class AddContainerEntitiesType < ActiveRecord::Migration
  class ContainerNode < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class Container < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class ContainerGroup < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    add_column :container_nodes, :type, :string
    say_with_time("Update ContainerNodes type to ContainerNodeKubernetes") do
      ContainerNode.update_all(:type => "ContainerNodeKubernetes")
    end
    add_column :containers, :type, :string
    say_with_time("Update Containers type to ContainerKubernetes") do
      Container.update_all(:type => "ContainerKubernetes")
    end
    add_column :container_groups, :type, :string
    say_with_time("Update ContainerGroups type to ContainerGroupKubernetes") do
      ContainerGroup.update_all(:type => "ContainerGroupKubernetes")
    end
  end

  def down
    remove_column :container_nodes, :type
    remove_column :containers, :type
    remove_column :container_groups, :type
  end
end
