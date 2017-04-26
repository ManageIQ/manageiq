def create_provision_requests(vm_base_name, num_of_vms, args)
  (1..num_of_vms).collect do |num|
    args[2]['vm_name'] = vm_base_name + "_" + num.to_s
    $evm.execute('create_provision_request', *args)
  end
end

def check_state(finished, fail)
  if finished
    $evm.root['ae_result'] = "ok"
  elsif fail
    $evm.root['ae_result'] = "error"
    $evm.log(:error, '*********  Provision failed  ************')
  else
    $evm.log(:info, "*********  Provision isnt finished re-trying in 1 min  ************")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
  end
end

def provision_request(vm_attr, type)
  num_of_vms = vm_attr[:number_of_vms].to_i
  args       = ['1.1', vm_attr[:templateFields],
                vm_attr[:vmFields], vm_attr[:requester],
                nil, vm_attr[:ws_values], nil, nil]
  request_ids = create_provision_requests(args[2]['vm_name'], num_of_vms, args).collect(&:id)
  $evm.root['automation_task'].automation_request.set_option("#{type}_request_ids", request_ids)
end

def start_provisioning
  $evm.log(:info, '*********  starting provision  ************')
  provision_request($evm.root['automation_task'].automation_request.options[:attrs][:nodes_provision], "node")
  provision_request($evm.root['automation_task'].automation_request.options[:attrs][:masters_provision], "master")
end

def provision
  $evm.log(:info, "********************** provision ***************************")
  $evm.root['container_deployment'] ||= $evm.vmdb(:container_deployment).find(
    $evm.root['automation_task'].automation_request.options[:attrs][:deployment_id]
  )
  start_provisioning unless $evm.root['container_deployment'].provision_started?
  $evm.root['state']                   = "provision"
  $evm.root['automation_task'].message = "Provisioning"
  $evm.log(:info, '*********  checking state of machines   ************')
  finished, fail = $evm.root['container_deployment'].provision_vms_status
  check_state(finished, fail)
end

begin
  provision
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = "Error: #{err.message}"
  exit MIQ_ERROR
end
