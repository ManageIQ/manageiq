# Second step - wait until instance get ready for resize confirm

vm = $evm.root['vm']

if vm.validate_resize_confirm
  # Raise automation event: request_pending
  $evm.root["miq_request"].pending
  exit MIQ_OK
end

# TODO: where revert?
