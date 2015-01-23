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
      save_child_inventory(manager, hashes, [:customization_scripts, :operating_system_flavors], target)
      manager.save
    end

    def save_customization_scripts_inventory(manager, hashes, target)
      hash_contains_all_values = target.nil? || manager == target
      save_inventory_assoc(:customization_scripts, manager, hashes, hash_contains_all_values, "manager_ref")
    end

    def save_operating_system_flavors_inventory(manager, hashes, target)
      hash_contains_all_values = target.nil? || manager == target
      hashes.each do |hash|
        if hash["customization_scripts"]
          hash[:customization_script_ids] = hash["customization_scripts"].map { |cp| cp[:id] }
        end
      end
      save_inventory_assoc(:operating_system_flavors, manager, hashes, hash_contains_all_values, "manager_ref", nil,
                           %w(customization_scripts))
    end
  end
end
