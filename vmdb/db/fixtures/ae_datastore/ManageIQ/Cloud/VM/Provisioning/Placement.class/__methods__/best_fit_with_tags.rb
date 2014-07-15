#
# Description: This method is used to find all hosts, datastores that match the required tag
#

# Get variables
prov = $evm.root["miq_provision"]
vm = prov.vm_template
raise "VM not specified" if vm.nil?
ems  = vm.ext_management_system
raise "EMS not found for VM [#{vm.name}" if ems.nil?
tags = prov.get_tags

# Log space required
$evm.log("info", "vm=[#{vm.name}], space required=[#{vm.provisioned_storage}]")

# STORAGE LIMITATIONS
STORAGE_MAX_VMS      = 0
storage_max_vms      = $evm.object['storage_max_vms']
storage_max_vms      = storage_max_vms.strip.to_i if storage_max_vms.kind_of?(String) && !storage_max_vms.strip.empty?
storage_max_vms      = STORAGE_MAX_VMS unless storage_max_vms.kind_of?(Numeric)

STORAGE_MAX_PCT_USED = 100
storage_max_pct_used = $evm.object['storage_max_pct_used']
storage_max_pct_used = storage_max_pct_used.strip.to_i if storage_max_pct_used.kind_of?(String) && !storage_max_pct_used.strip.empty?
storage_max_pct_used = STORAGE_MAX_PCT_USED unless storage_max_pct_used.kind_of?(Numeric)

host = storage = nil
min_registered_vms = nil
prov.eligible_hosts.each do |h|
  next unless h.power_state == "on"

  # Only consider hosts that have the required tags
  next unless tags.all? do |key, value|
    if value.kind_of?(Array)
      value.any? { |v| h.tagged_with?(key, v) }
    else
      h.tagged_with?(key, value)
    end
  end

  nvms = h.vms.length

  # Only consider storages that have the required tags
  storages = h.storages.select do |s|
    tags.all? do |key, value|
      if value.kind_of?(Array)
        value.any? { |v| s.tagged_with?(key, v) }
      else
        s.tagged_with?(key, value)
      end
    end
  end

  # Filter out storages that do not have enough free space for the Vm
  storages = storages.select do |s|
    if s.free_space > vm.provisioned_storage
      true
    else
      $evm.log("info", "Skipping Datastore: [#{s.name}], not enough free space for VM. Available: [#{s.free_space}], Needs: [#{vm.provisioned_storage}]")
      false
    end
  end
  # Filter out storages number of VMs is greater than the max number of VMs
  storages = storages.select do |s|
    if (storage_max_vms == 0) || (s.vms.size < storage_max_vms)
      true
    else
      $evm.log("info", "Skipping Datastore: [#{s.name}], max number of VMs exceeded")
      false
    end
  end
  # Filter out storages where percent used is greater than the max.
  storages = storages.select do |s|
    if (storage_max_pct_used == 100) || (s.v_used_space_percent_of_total < storage_max_pct_used)
      true
    else
      $evm.log("info", "Skipping Datastore: [#{s.name}], percent of used space is exceeded")
      false
    end
  end
  # if minimum registered vms is nil or number of vms on a host is greater than nil
  if min_registered_vms.nil? || nvms < min_registered_vms
    s = storages.sort { |a, b| a.free_space <=> b.free_space }.last
    unless s.nil?
      host    = h
      storage = s
      min_registered_vms = nvms
    end
  end
end

# Set host and storage
obj = $evm.object
obj["host"]    = host    unless host.nil?
obj["storage"] = storage unless storage.nil?

$evm.log("info", "vm=[#{vm.name}] host=[#{host}] storage=[#{storage}]")
