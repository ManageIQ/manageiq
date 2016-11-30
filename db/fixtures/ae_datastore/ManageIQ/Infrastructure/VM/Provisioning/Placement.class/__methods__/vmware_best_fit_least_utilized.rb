#
# Description: This method is used to find all hosts, datastores that are the least utilized
#
$evm.log("info", "Args:    #{MIQ_ARGS.inspect}")

# Get variables
prov = $evm.root["miq_provision"]
vm = prov.vm_template
raise "VM not specified" if vm.nil?
ems = vm.ext_management_system
raise "EMS not found for VM [#{vm.name}]" if ems.nil?

# Log space required
$evm.log("info", "vm=[#{vm.name}], space required=[#{vm.provisioned_storage}]")

host = storage = nil
min_registered_vms = nil
prov.eligible_hosts.each do |h|
  next unless h.power_state == "on"
  nvms = h.vms.length
  if min_registered_vms.nil? || nvms < min_registered_vms
    storages = h.writable_storages.find_all { |s| s.free_space > vm.provisioned_storage } # Filter out storages that do not have enough free space for the Vm
    s = storages.sort { |a, b| a.free_space <=> b.free_space }.last
    unless s.nil?
      host    = h
      storage = s
      min_registered_vms = nvms
    end
  end
end

# Set host and storage
prov.set_host(host) if host
prov.set_storage(storage) if storage

$evm.log("info", "vm=[#{vm.name}] host=[#{host}] storage=[#{storage}]")
