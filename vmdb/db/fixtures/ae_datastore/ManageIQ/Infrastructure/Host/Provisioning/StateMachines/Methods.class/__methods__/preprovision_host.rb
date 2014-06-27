###################################
#
# EVM Automate Method: PreProvision
#
# Notes: This method is used to Customize the provisioning request
#
###################################
begin
  @method = 'PreProvision'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  # Turn of verbose logging
  @debug = true

  #
  # Get variables
  #
  prov   = $evm.root['miq_host_provision']

  # prov.set_option(:gateway,'192.168.252.1')
  # prov.set_option(:ip_addr,'192.168.252.116')
  # prov.set_option(:dns_servers,'192.168.252.19')
  # prov.set_option(:subnet_mask,'255.255.254.0')
  # prov.set_option(:dns_suffixes,'manageiq.com')

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
