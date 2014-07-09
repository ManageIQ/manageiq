###################################
#
# EVM Automate Method: vmname
#
# Notes: This is the default vmnaming method
# 1. If VM Name was not chosen during dialog processing then use vm_prefix
#    from dialog else use model and [:environment] tag to generate name
# 2. Else use VM name chosen in dialog
# 3. Then add 3 digit suffix to vm_name
# 4. Added support for dynamic service naming
#
###################################
begin
  @method = 'vmname'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  # $evm.root.attributes.sort.each { |k, v| $evm.log("info", "#{@method} - Root:<$evm.root> Attributes - #{k}: #{v}")}

  $evm.log("info", "#{@method} - Detected vmdb_object_type:<#{$evm.root['vmdb_object_type']}>") if @debug

  prov = $evm.root['miq_provision_request'] || $evm.root['miq_provision'] || $evm.root['miq_provision_request_template']
  # $evm.log("info", "#{@method} - Inspecting prov:<#{prov.inspect}>") if @debug

  vm_name = prov.get_option(:vm_name).to_s.strip
  number_of_vms_being_provisioned = prov.get_option(:number_of_vms)
  diamethod = prov.get_option(:vm_prefix).to_s.strip

  # If no VM name was chosen during dialog
  if vm_name.blank? || vm_name == 'changeme'
    vm_prefix = nil
    vm_prefix ||= $evm.object['vm_prefix']
    $evm.log("info", "#{@method} - vm_name from dialog:<#{vm_name.inspect}> vm_prefix from dialog:<#{diamethod.inspect}> vm_prefix from model:<#{vm_prefix.inspect}>") if @debug

    # Get Provisioning Tags for VM Name
    tags = prov.get_tags
    $evm.log("info", "#{@method} - Provisioning Object Tags: #{tags.inspect}") if @debug

    # Set a Prefix for VM Naming
    if diamethod.blank?
      vm_name = vm_prefix
    else
      vm_name = diamethod
    end
    $evm.log("info", "#{@method} - VM Naming Prefix: <#{vm_name}>") if @debug

    # Check :environment tag
    env = tags[:environment]

    # If environment tag is not nil
    unless env.nil?
      $evm.log("info", "#{@method} - Environment Tag: <#{env}> detected") if @debug
      # Get the first 3 characters of the :environment tag
      env_first = env[0, 3]

      vm_name =  "#{vm_name}#{env_first}"
      $evm.log("info", "#{@method} - Updating VM Name: <#{vm_name}>") if @debug
    end
    derived_name = "#{vm_name}$n{3}"
  else
    if number_of_vms_being_provisioned == 1
      derived_name = "#{vm_name}"
    else
      derived_name = "#{vm_name}$n{3}"
    end
  end

  $evm.object['vmname'] = derived_name
  $evm.log("info", "#{@method} - VM Name: <#{derived_name}>") if @debug

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
