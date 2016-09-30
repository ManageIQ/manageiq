#
# Calling order for EmsCloud
# - ems
#   - cloud_object_store_containers
#     - cloud_object_store_objects
#

module EmsRefresh::SaveInventorySwift
  def save_ems_swift_inventory(ems, hashes, target = nil)
    target = ems if target.nil?
    log_header = "EMS: [#{ems.name}], id: [#{ems.id}]"

    # Check if the data coming in reflects a complete removal from the ems
    if hashes.blank?
      target.disconnect_inv
      return
    end

    _log.info("#{log_header} Saving EMS Swift Inventory...")
    if debug_trace
      require 'yaml'
      _log.debug "#{log_header} hashes:\n#{YAML.dump(hashes)}"
    end

    child_keys = [
      :cloud_object_store_containers,
      :cloud_object_store_objects,
    ]

    # Save and link other subsections
    save_swift_child_inventory(ems, hashes, child_keys, target)

    ems.save!
    hashes[:id] = ems.id

    _log.info("#{log_header} Saving EMS Swift Inventory...Complete")

    ems
  end

  def save_swift_child_inventory(obj, hashes, child_keys, *args)
    child_keys.each { |k| send("save_swift_#{k}_inventory", obj, hashes[k], *args) if hashes.key?(k) }
  end

  def save_swift_cloud_object_store_containers_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.cloud_object_store_containers.reset
    deletes = if target == ems
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:ems_id]          = ems.id
      h[:cloud_tenant_id] = h.fetch_path(:tenant, :id)
    end

    save_inventory_multi(ems.cloud_object_store_containers, hashes, deletes, [:ems_ref], nil, :tenant)
    store_ids_for_new_records(ems.cloud_object_store_containers, hashes, :ems_ref)
  end

  def save_swift_cloud_object_store_objects_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.cloud_object_store_objects.reset
    deletes = if target == ems
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:ems_id]                          = ems.id
      h[:cloud_tenant_id]                 = h.fetch_path(:tenant, :id)
      h[:cloud_object_store_container_id] = h.fetch_path(:container, :id)
    end

    save_inventory_multi(ems.cloud_object_store_objects, hashes, deletes, [:ems_ref], nil, [:tenant, :container])
    store_ids_for_new_records(ems.cloud_object_store_objects, hashes, :ems_ref)
  end
end
