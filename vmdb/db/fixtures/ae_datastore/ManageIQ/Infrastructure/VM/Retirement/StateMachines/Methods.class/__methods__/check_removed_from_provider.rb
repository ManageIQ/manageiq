#
# Description: This method checks to see if the VM has been removed from the provider
#

vm = $evm.root['vm']

$evm.root['ae_result'] = 'ok'

if vm && $evm.get_state_var('vm_removed_from_provider')
  if vm.ext_management_system
    vm.refresh
    $evm.root['ae_result']	   = 'retry'
    $evm.root['ae_retry_interval'] = '60.seconds'
  end
end
