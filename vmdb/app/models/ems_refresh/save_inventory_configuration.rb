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
      save_inventory_assoc(:configuration_profiles, manager, hashes, delete_missing_records, :manager_ref)
    end

    def save_configured_systems_inventory(manager, hashes, target)
      delete_missing_records = target.nil? || manager == target
      hashes.each do |hash|
        if hash.key?(:configuration_profile)
          hash[:configuration_profile_id] = hash.fetch_path(:configuration_profile, :id)
        else # single refresh
          configuration_profile = manager.configuration_profiles.find_by_manager_ref(hash[:configuration_profile_ref])
          if configuration_profile
            hash[:configuration_profile_id] = configuration_profile.id
          else
            # do not have configuration_profile, need to do a complete configuration refresh
            hashes[:needs_configuration_refresh] = true
          end
        end
      end
      save_inventory_assoc(:configured_systems, manager, hashes, delete_missing_records, :manager_ref, nil,
                           [:configuration_profile, :configuration_profile_ref])
    end
  end
end
