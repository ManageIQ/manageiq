# Initial step - call resize method on instance to start it's resize process

def log(text, category = 'info')
  $evm.log category, text
end

vm = $evm.root['vm']
flavor = $evm.vmdb('flavor').find_by_id($evm.root['flavor_id'])

log "Starting resize instance #{vm.name} to #{flavor} flavor..."

if flavor.present? && vm.validate_resize
  # call execute action
  vm.resize flavor
else
  $evm.root['ae_result'] = 'error'
  $evm.object['reason'] = 'Validation has failed. #TODO'
  exit MIQ_ERROR
end

exit MIQ_OK
