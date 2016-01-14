class RenameContainerGroupNodeSelectorsToSelectors < ActiveRecord::Migration
  include MigrationHelper

  def up
    if CustomAttribute.table_exists?
      # We want to change CustomAttribute only for ContainerGroup.selector_parts
      # In the up case:
      #   Only ContainerGroup use the scope name "node_selectors" so we can just,
      #   change the section field without checking relations to ContainerGroup.
      say_with_time("Renaming node_selectors to selectors in '#{CustomAttribute.table_name}'") do
        CustomAttribute.where(:section => "node_selectors").update_all(:section => "selectors")
      end
    end
  end

  def down
    # We want to change CustomAttribute only for ContainerGroup.selector_parts
    # In the down case:
    #   This is more tricky :-)
    #   We want to select only CustomAttribute belonging to a ContainerGroup.selector_parts.
    #   The scope name "selectors" is used in other classes. We need to change only
    #   container_group.selector_parts.
    if ContainerGroup.table_exists?
      say_with_time("Renaming selectors to node_selectors in '#{ContainerGroup.table_name}'") do
        ContainerGroup.all.each do |container_group|
          container_group.selector_parts.where(:section => "selectors").update_all(:section => "node_selectors")
        end
      end
    end
  end
end
