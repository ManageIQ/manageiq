#
# Calling order for EmsPhysicalInfra:
# - ems
#   - physical_servers
#

module EmsRefresh::SaveInventoryPhysicalInfra
  def save_ems_physical_infra_inventory(ems, hashes, target = nil)
    target = ems if target.nil?
    log_header = "EMS: [#{ems.name}], id: [#{ems.id}]"

    # Check if the data coming in reflects a complete removal from the ems
    if hashes.blank?
      target.disconnect_inv
      return
    end

    _log.info("#{log_header} Saving EMS Inventory...")
    if debug_trace
      require 'yaml'
      _log.debug "#{log_header} hashes:\n#{YAML.dump(hashes)}"
    end

    child_keys = [
      :physical_servers,
    ]

    # Save and link other subsections
    save_child_inventory(ems, hashes, child_keys, target)

    ems.save!
    hashes[:id] = ems.id

    _log.info("#{log_header} Saving EMS Inventory...Complete")

    ems
  end

  def save_physical_servers_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.physical_servers.reset
    deletes = if target == ems
                :use_association
              else
                []
              end

    child_keys = [:computer_system]
    save_inventory_multi(ems.physical_servers, hashes, deletes, [:ems_ref], child_keys)
    store_ids_for_new_records(ems.physical_servers, hashes, :ems_ref)
  end
end
