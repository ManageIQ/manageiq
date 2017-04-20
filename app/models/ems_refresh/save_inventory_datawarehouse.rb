module EmsRefresh::SaveInventoryDatawarehouse
  def save_ems_datawarehouse_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    child_keys = [:datawarehouse_nodes, :cluster_attributes]
    # Save and link other subsections
    child_keys.each do |k|
      send("save_#{k}_inventory", ems, hashes[k], target)
    end

    ems.save!
  end

  def save_cluster_attributes_inventory(entity, hashes, target = nil)
    save_custom_attribute_attribute_inventory(entity, :cluster_attributes, hashes, target)
  end

  def save_datawarehouse_nodes_inventory(ems, hashes, target = nil)
    return if hashes.nil?

    ems.datawarehouse_nodes.reset
    deletes = if target.kind_of?(ExtManagementSystem)
                :use_association
              else
                []
              end

    save_inventory_multi(ems.datawarehouse_nodes, hashes, deletes, [:ems_ref],
                         [], [], true)
    store_ids_for_new_records(ems.datawarehouse_nodes, hashes, :ems_ref)
  end
end
