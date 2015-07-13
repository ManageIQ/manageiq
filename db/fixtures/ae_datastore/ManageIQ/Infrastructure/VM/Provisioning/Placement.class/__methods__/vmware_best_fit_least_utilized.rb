#
# Description: This method is used to find all hosts, datastores that are the least utilized
#
def root_folder(host, data_center)
  host.ext_management_system.ems_folders.detect { |f| f.folder_path == "Datacenters/#{data_center}/vm" }
end

def set_folder(prov, host, vm)
  host_dc = host.ems_cluster.v_parent_datacenter
  $evm.log("info", "selected datacenter [#{host_dc}]")
  matching_folder = vm.v_owning_blue_folder_path.sub("/#{vm.v_owning_datacenter}/", "/#{host_dc}/")
  folder = prov.eligible_folders.detect { |f| f.folder_path == matching_folder }
  folder ||= root_folder(host, host_dc)
  if folder
    $evm.log("info", "selected folder [#{folder.folder_path}]")
    # prov.set_folder is not being used intentionally since it currently does not support root vm folders
    prov.set_option(:placement_folder_name, [folder.id, folder.name])
  end
end
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
if host
  prov.set_host(host)
  # set folder if it is not set already
  set_folder(prov, host, vm) if prov.get_option(:placement_folder_name).nil?
end

prov.set_storage(storage) if storage

$evm.log("info", "vm=[#{vm.name}] host=[#{host}] storage=[#{storage}]")
