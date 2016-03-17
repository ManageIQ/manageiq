class InlineEmsId < ActiveRecord::Migration
  class ContainerDefinition < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class ContainerGroup < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class Container < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI

    belongs_to :container_definition, :class_name => "InlineEmsId::ContainerDefinition"
    has_one    :container_group, :through => :container_definition, :class_name => "InlineEmsId::ContainerGroup"
  end

  class ContainerDefinition < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI

    belongs_to :container_group, :class_name => "InlineEmsId::ContainerGroup"
  end

  def up
    add_columns
    update_columns
  end

  def add_columns
    add_column :containers, :ems_id, :bigint
    add_column :container_definitions, :ems_id, :bigint
  end

  def update_columns
    say_with_time("Inline ems_id in containers") do
      Container.includes(:container_definitions => :container_group).all.each do |container|
        container.update_attribute(:ems_id, container.container_group.ems_id)
      end
    end

    say_with_time("add ems_id to container definitions") do
      ContainerDefinition.includes(:container_group).all.each do |container_definition|
        container_definition.update_attribute(:ems_id, container_definition.container_group.ems_id)
      end
    end
  end

  def down
    remove_column :containers, :ems_id
    remove_column :container_definitions, :ems_id
  end
end
