###################################
#
# EVM Automate Method: least_utilized
#
# Notes: This method is used to find all hosts, datastores that are the least utilized
#
###################################
begin
  @method = 'least_utilized'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  # Turn of verbose logging
  @debug = true

  # Dump incoming Arguments
  $evm.log("info", "Args:    #{MIQ_ARGS.inspect}") if @debug

  #
  # Get variables
  #
  prov = $evm.root["miq_provision"]
  vm = prov.vm_template
  raise "VM not specified" if vm.nil?
  ems  = vm.ext_management_system
  raise "EMS not found for VM [#{vm.name}" if vm.nil?

  # Log space required
  $evm.log("info", "Inline Method: <#{@method}> -- vm=[#{vm.name}], space required=[#{vm.provisioned_storage}]")

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

  $evm.log("info", "Inline Method: <#{@method}> -- vm=[#{vm.name}] host=[#{host}] storage=[#{storage}]")

  #
  # Exit method
  #
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "<#{@method}>: [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
