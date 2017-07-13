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
    discover_ip_physical_infra(ems)

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

    child_keys = [:computer_system, :asset_details, :hosts]
    save_inventory_multi(ems.physical_servers, hashes, deletes, [:ems_ref], child_keys)
    store_ids_for_new_records(ems.physical_servers, hashes, :ems_ref)
  end

  #
  # Saves asset details information of a resource
  #
  def save_asset_details_inventory(parent, hash)
    return if hash.nil?
    save_inventory_single(:asset_details, parent, hash)
  end

  def ipaddress?(hostname)
    IPAddr.new(hostname)
    return true
  rescue
    return false
  end

  def resolve_hostname(ipaddress, ems)
    ems.hostname = "https://#{Resolv.getname(ipaddress)}/"
    _log.info("EMS ID: #{ems.id}" + " Resolved hostname successfully.")
  rescue => err
    _log.warn("EMS ID: #{ems.id}" + " It's not possible resolve hostname of the physical infra, #{err}.")
  end

  def resolve_ip_address(hostname, ems)
    ems.ipaddress = Resolv.getaddress(hostname)
    _log.info("EMS ID: #{ems.id}" + " Resolved ip address successfully.")
  rescue => err
    _log.warn("EMS ID: #{ems.id}" + " It's not possible resolve ip address of the physical infra, #{err}.")
  end

  def discover_ip_physical_infra(ems)
    hostname = URI.parse(ems.hostname).host || URI.parse(ems.hostname).path
    if ems.ipaddress.blank?
      resolve_ip_address(hostname, ems)
    end
    if ipaddress?(hostname)
      resolve_hostname(hostname, ems)
    end
  end
end
