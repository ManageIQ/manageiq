# Calling order for EmsForeman
#
# - ems
#   - customization_scripts (foreman MediumScripts, PtableScripts)
#   - operating_system_flavors (foreman OperatingSystem)
#     - customization_script[] (links)
module EmsRefresh
  module SaveInventoryProvisioning
    def save_provisioning_manager_inventory(manager, hashes, target = nil)
      return if hashes.nil?
      child_keys = [
        :customization_scripts,
        :operating_system_flavors,
        :configuration_locations,
        :configuration_organizations,
        :configuration_tags,
      ]
      save_child_inventory(manager, hashes, child_keys, target)
      manager.save
    end

    def save_customization_scripts_inventory(manager, hashes, target)
      delete_missing_records = target.nil? || manager == target
      save_inventory_assoc(manager.customization_scripts, hashes, delete_missing_records, [:type, :manager_ref])
    end

    def save_operating_system_flavors_inventory(manager, hashes, target)
      delete_missing_records = target.nil? || manager == target
      hashes.each do |hash|
        if hash[:customization_scripts]
          hash[:customization_script_ids] = hash[:customization_scripts].map { |cp| cp[:id] }
        end
      end
      save_inventory_assoc(manager.operating_system_flavors, hashes, delete_missing_records, [:manager_ref], nil,
                           [:customization_scripts])
    end

    def save_configuration_locations_inventory(manager, hashes, target)
      delete_missing_records = target.nil? || manager == target
      save_inventory_assoc(manager.configuration_locations, hashes, delete_missing_records, [:manager_ref])
      link_children_references(manager.configuration_locations)
    end

    def save_configuration_organizations_inventory(manager, hashes, target)
      delete_missing_records = target.nil? || manager == target
      save_inventory_assoc(manager.configuration_organizations, hashes, delete_missing_records, [:manager_ref])
      link_children_references(manager.configuration_organizations)
    end

    def save_configuration_tags_inventory(manager, hashes, target)
      delete_missing_records = target.nil? || manager == target
      save_inventory_assoc(manager.configuration_tags, hashes, delete_missing_records, [:type, :manager_ref])
    end
  end
end
