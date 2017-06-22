class UseDeletedInContainersTables < ActiveRecord::Migration[5.0]
  class ContainerDefinition < ActiveRecord::Base; end

  class ContainerGroup < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class ContainerImage < ActiveRecord::Base; end

  class ContainerProject < ActiveRecord::Base; end

  class Container < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def disconnect_to_soft_delete(model)
    model.where.not(:deleted_on => nil).update_all("ems_id = old_ems_id")
  end

  def soft_delete_to_disconnect(model)
    model.where.not(:deleted_on => nil).update_all(:ems_id => nil)
  end

  def up
    say_with_time("Change ':deleted_on not nil' :ems_id to :old_ems_id for ContainerDefinition") do
      disconnect_to_soft_delete(ContainerDefinition)
    end

    say_with_time("Change ':deleted_on not nil' :ems_id to :old_ems_id for ContainerGroup") do
      disconnect_to_soft_delete(ContainerGroup)
    end

    say_with_time("Change ':deleted_on not nil' :ems_id to :old_ems_id for ContainerImages") do
      disconnect_to_soft_delete(ContainerImage)
    end

    say_with_time("Change ':deleted_on not nil' :ems_id to :old_ems_id for ContainerProject") do
      disconnect_to_soft_delete(ContainerProject)
    end

    say_with_time("Change ':deleted_on not nil' :ems_id to :old_ems_id for Container") do
      disconnect_to_soft_delete(Container)
    end
  end

  def down
    say_with_time("Change ':deleted_on not nil' :ems_id to nil for ContainerDefinition") do
      soft_delete_to_disconnect(ContainerDefinition)
    end

    say_with_time("Change ':deleted_on not nil' :ems_id to nil for ContainerGroup") do
      soft_delete_to_disconnect(ContainerGroup)
    end

    say_with_time("Change ':deleted_on not nil' :ems_id to nil for ContainerImages") do
      soft_delete_to_disconnect(ContainerImage)
    end

    say_with_time("Change ':deleted_on not nil' :ems_id to nil for ContainerProject") do
      soft_delete_to_disconnect(ContainerProject)
    end

    say_with_time("Change ':deleted_on not nil' :ems_id to nil for Container") do
      soft_delete_to_disconnect(Container)
    end
  end
end
