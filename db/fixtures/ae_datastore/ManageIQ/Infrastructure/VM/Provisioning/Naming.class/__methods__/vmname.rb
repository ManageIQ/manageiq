#
# Description: This is the default vmnaming method
# 1. If VM Name was not chosen during dialog processing then use vm_prefix
#    from dialog else use model and [:environment] tag to generate name
# 2. Else use VM name chosen in dialog
# 3. Then add 3 digit suffix to vm_name
# 4. Added support for dynamic service naming
#

$evm.log("info", "Detected vmdb_object_type:<#{$evm.root['vmdb_object_type']}>")

prov = $evm.root['miq_provision_request'] || $evm.root['miq_provision'] || $evm.root['miq_provision_request_template']

vm_name = prov.get_option(:vm_name).to_s.strip
number_of_vms_being_provisioned = prov.get_option(:number_of_vms)
diamethod = prov.get_option(:vm_prefix).to_s.strip

# If no VM name was chosen during dialog
if vm_name.blank? || vm_name == 'changeme'
  vm_prefix = nil
  vm_prefix ||= $evm.object['vm_prefix']
  $evm.log("info", "vm_name from dialog:<#{vm_name.inspect}> vm_prefix from dialog:<#{diamethod.inspect}> vm_prefix from model:<#{vm_prefix.inspect}>")

  # Get Provisioning Tags for VM Name
  tags = prov.get_tags
  $evm.log("info", "Provisioning Object Tags: #{tags.inspect}")

  # Set a Prefix for VM Naming
  if diamethod.blank?
    vm_name = vm_prefix
  else
    vm_name = diamethod
  end
  $evm.log("info", "VM Naming Prefix: <#{vm_name}>")

  # Check :environment tag
  env = tags[:environment]

  # If environment tag is not nil
  unless env.nil?
    $evm.log("info", "Environment Tag: <#{env}> detected")
    # Get the first 3 characters of the :environment tag
    env_first = env[0, 3]

    vm_name =  "#{vm_name}#{env_first}"
    $evm.log("info", "Updating VM Name: <#{vm_name}>")
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
$evm.log("info", "VM Name: <#{derived_name}>")
