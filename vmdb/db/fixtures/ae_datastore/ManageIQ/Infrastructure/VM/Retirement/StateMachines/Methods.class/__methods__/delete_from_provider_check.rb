#
# Description: This method checks to see if the VM has been deleted from the provider
#

vm = $evm.root['vm']

category = "lifecycle"
tag = "retire_full"

miq_guid = /\w*MIQ\sGUID/i
if vm.v_annotation =~  miq_guid
  vm_was_provisioned = true
else
  vm_was_provisioned = false
end

if vm && (vm_was_provisioned || vm.miq_provision || vm.tagged_with?(category, tag))
  $evm.log('info', "Checking if VM: <#{vm.name}> has been deleted from the provider. ")
  if vm.archived || vm.orphaned
    # Bump State
    $evm.root['ae_result'] = 'ok'
  else
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '15.seconds'
  end
else
  # Bump State
  $evm.root['ae_result'] = 'ok'
end
