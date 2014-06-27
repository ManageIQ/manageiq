###################################
#
# EVM Automate Method: best_fit_cluster
#
###################################
begin
  @method = 'best_fit_cluster'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  # Turn of verbose logging
  @debug = false

  #
  # Get variables
  #
  prov = $evm.root["miq_provision"]
  vm = prov.vm_template
  raise "VM not specified" if vm.nil?
  user = prov.miq_request.requester
  raise "User not specified" if user.nil?
  ems  = vm.ext_management_system
  raise "EMS not found for VM [#{vm.name}" if ems.nil?

  $evm.log("info", "Inline Method: <#{@method}> -- vm=[#{vm.name}]")

  cluster = vm.ems_cluster
  current_obj = $evm.current
  $evm.log("info", "Inline Method: #{@method} -- Selected Cluster: [#{cluster.nil? ? "nil" : cluster.name}]")

  # Set cluster
  current_obj["cluster"] = cluster unless cluster.nil?
  $evm.log("info", "Inline Method: <#{@method}> -- vm=[#{vm.name}] cluster=[#{cluster}]")

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
