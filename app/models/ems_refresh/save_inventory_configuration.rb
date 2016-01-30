# Calling order for EmsForeman
#
# - ems
#   - configuration_profiles (foreman HostGroup)
#     - operating_system_flavor (links)
#     - customization_script_ptable (link)
#     - customization_script_medium (link)
#   - configured_systems (foreman Host)
#     - operating_system_flavor (links)
#     - customization_scripts (links)
## ? use guid?
module EmsRefresh
  module SaveInventoryConfiguration
    def save_configuration_manager_inventory(manager, hashes, target = nil)
      return if hashes.nil?
      save_child_inventory(manager, hashes, [:configuration_profiles, :configured_systems], target)
      manager.save
    end

    def save_configuration_profiles_inventory(manager, hashes, target)
      delete_missing_records = target.nil? || manager == target
      save_inventory_assoc(manager.configuration_profiles, hashes, delete_missing_records, [:manager_ref])

      link_children_references(manager.configuration_profiles)
    end

    def save_configured_systems_inventory(manager, hashes, target)
      delete_missing_records = target.nil? || manager == target
      # these records are cross referenced to the hashes
      # get the id out and store in this record
      hashes.each do |hash|
        hash[:configuration_profile_id] = hash.fetch_path(:configuration_profile, :id)
      end
      save_inventory_assoc(manager.configured_systems, hashes, delete_missing_records, [:manager_ref], nil,
                           [:configuration_profile])
    end
  end
end
