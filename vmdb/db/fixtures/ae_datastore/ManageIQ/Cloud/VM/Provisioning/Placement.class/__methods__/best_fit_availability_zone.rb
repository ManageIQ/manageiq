###################################
#
# CFME Automate Method: best_fit_availability_zone
#
###################################
begin
  @method = 'best_fit_cluster'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  # Get variables
  prov     = $evm.root["miq_provision"]
  template = prov.vm_template
  raise "Template not specified" if template.nil?
  provider = template.ext_management_system
  raise "Provider not found for template [#{template.name}" if provider.nil?

  availability_zones = provider.availability_zones
  current_obj = $evm.current
  current_obj["availability_zone"] = availability_zones.first

  $evm.log("info", "Inline Method: <#{@method}> -- Template=[#{template.name}]   AvailabilityZone=[#{current_obj["availability_zone"]}]")

rescue => err
  # Rescue Errors
  $evm.log("error", "<#{@method}>: [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT

else
  # Exit method OK
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Ended")
  exit MIQ_OK
end
