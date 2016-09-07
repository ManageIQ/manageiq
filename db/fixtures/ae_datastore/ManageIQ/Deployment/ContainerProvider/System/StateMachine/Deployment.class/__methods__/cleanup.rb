def cleanup
  $evm.log(:info, "********************** Cleanup ***************************")
  $evm.root['container_deployment'] ||= $evm.vmdb(:container_deployment).find(
    $evm.root['automation_task'].automation_request.options[:attrs][:deployment_id]
  )
  $evm.log(:info, $evm.root['ae_result'])
  $evm.log(:info, $evm.root['deployment_method'])

  if $evm.root['ae_result'].include?("error") && $evm.root['deployment_method'] == "provision"
    ($evm.root['container_deployment'].find_vm_by_type("node") + $evm.root['container_deployment'].find_vm_by_type("master")).each do |vm|
      $evm.log('info', "Removing VM:<#{vm.name}>")
      vm.remove_from_disk(false)
    end
  end
  $evm.root['ae_result'] = "ok"
  $evm.root['automation_task'].message = "successful deployment cleanup"
  $evm.log(:info, "State: #{$evm.root['ae_state']} | Result: #{$evm.root['ae_result']} | Message: #{$evm.root['automation_task'].message}")
end

begin
  cleanup
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = "Error: #{err.message}"
  exit MIQ_ERROR
end
