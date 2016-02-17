def log_state
  $evm.log(:info, "#{$evm.root['Phase']} : #{$evm.root['ae_result']} : #{$evm.root['Message']}")
  $evm.log(:info, "Next State: #{$evm.root['ae_next_state']}") if $evm.root['ae_next_state']
end

log_state