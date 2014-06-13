###################################
#
# EVM Automate Method: PostProvision_Clone_to_VM
#
# Notes: This method is used to customize the provisioning object prior to provisioning
#
###################################
begin
  @method = 'PostProvision_Clone_to_VM'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  #
  # Get Variables
  #
  prov = $evm.root["miq_provision"]
  $evm.log("info", "#{@method} - Inspecting Provisioning Object: #{prov.inspect}") if @debug

  # Get Provision Type
  prov_type = prov.provision_type
  $evm.log("info", "#{@method} - Provision Type: <#{prov_type}>") if @debug

  # Get template
  template = prov.vm_template
  $evm.log("info", "#{@method} - Inspecting Template Object: #{template.inspect}") if @debug

  tags = template.tags
  $evm.log("info", "#{@method} - Inspecting Template Tags: #{tags.inspect}") if @debug

  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
