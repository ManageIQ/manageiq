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
    s = h.storages.sort { |a, b| a.free_space <=> b.free_space }.last
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
