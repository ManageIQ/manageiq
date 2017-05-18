# Calling order
#
# - ems
#   - configuration_profiles
#     - operating_system_flavor (links)
#     - customization_script_ptable (link)
#     - customization_script_medium (link)
#   - configured_systems
#     - operating_system_flavor (links)
#     - customization_scripts (links)
## ? use guid?
module EmsRefresh
  module SaveInventoryAutomation
    def save_automation_manager_inventory(manager, hashes, target = nil)
      return if hashes.nil?
      save_child_inventory(manager, hashes, [:ems_folders, :configuration_profiles, :configured_systems, :configuration_scripts], target)
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
        hash[:inventory_root_group_id]  = hash.fetch_path(:inventory_root_group, :id)
      end
      save_inventory_assoc(manager.configured_systems, hashes, delete_missing_records, [:manager_ref], nil, [:configuration_profile, :inventory_root_group])
    end

    def save_configuration_scripts_inventory(manager, hashes, target)
      delete_missing_records = target.nil? || manager == target
      # these records are cross referenced to the hashes
      # get the id out and store in this record
      hashes.each { |hash| hash[:inventory_root_group_id] = hash.fetch_path(:inventory_root_group, :id) }
      save_inventory_assoc(manager.configuration_scripts, hashes, delete_missing_records, [:manager_ref], nil, [:configuration_script, :inventory_root_group])
    end

    def save_ems_folders_inventory(manager, hashes, target)
      delete_missing_records = target.nil? || manager == target
      save_inventory_assoc(manager.inventory_groups, hashes, delete_missing_records, [:ems_ref], nil, [:ems_folder])
    end
  end
end
