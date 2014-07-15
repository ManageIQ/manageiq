#
# Description: This method checks to see if the VM is unregistered from the provider
#

vm = $evm.root['vm']

unless vm.nil?
  if !vm.registered?
    # Bump State
    $evm.log('info', "VM:<#{vm.name}> has been unregistered from EMS")
    $evm.root['ae_result'] = 'ok'
  else
    $evm.log('info', "VM:<#{vm.name}> is on Host:<#{vm.host}>, EMS:<#{vm.ext_management_system.name}>")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '15.seconds'
  end
end
