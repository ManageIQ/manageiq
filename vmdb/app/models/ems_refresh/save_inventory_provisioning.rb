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
        :configuration_organizations
      ]
      save_child_inventory(manager, hashes, child_keys, target)
      manager.save
    end

    def save_customization_scripts_inventory(manager, hashes, target)
      delete_missing_records = target.nil? || manager == target
      save_inventory_assoc(:customization_scripts, manager, hashes, delete_missing_records, [:type, :manager_ref])
    end

    def save_operating_system_flavors_inventory(manager, hashes, target)
      delete_missing_records = target.nil? || manager == target
      hashes.each do |hash|
        if hash[:customization_scripts]
          hash[:customization_scripts] = hash[:customization_scripts].map { |cp| cp[:ar_object] }
        end
      end
      save_inventory_assoc(:operating_system_flavors, manager, hashes, delete_missing_records, [:manager_ref])
    end

    def save_configuration_locations_inventory(manager, hashes, target)
      delete_missing_records = target.nil? || manager == target
      save_inventory_assoc(:configuration_locations, manager, hashes, delete_missing_records, [:manager_ref])
    end

    def save_configuration_organizations_inventory(manager, hashes, target)
      delete_missing_records = target.nil? || manager == target
      save_inventory_assoc(:configuration_organizations, manager, hashes, delete_missing_records, [:manager_ref])
    end
  end
end
