def get_custom_tag(type)
  type + "_#{$evm.root['automation_task'][:id]}"
end

def create_custom_tag(name)
  tag_name = "#{name}_#{$evm.root['automation_task'][:id]}"
  unless $evm.execute('tag_exists?', 'miq_openstack_deploy', tag_name)
    $evm.log(:info, "********************** creating tag ***************************")
    $evm.execute('tag_create',
                 'miq_openstack_deploy',
                 :name        => tag_name,
                 :description => tag_name)
  end
end

def tagged_tasks
  tasks = []
  $evm.vmdb('miq_provision_request').all.each do |prov|
    next unless prov.get_tags[:miq_openstack_deploy] &&
      (prov.get_tags[:miq_openstack_deploy].include?(get_custom_tag("master")) ||
        prov.get_tags[:miq_openstack_deploy].include?(get_custom_tag("node")))
    tasks << prov
  end
  tasks
end

def create_provision_requests(vm_base_name, num_of_vms, args, type)
  (1..num_of_vms).each do |num|
    args[2]['vm_name'] = vm_base_name + "_" + num.to_s
    request            = $evm.execute('create_provision_request', *args)
    request.add_tag("miq_openstack_deploy", type + '_' + $evm.root['automation_task'][:id].to_s)
  end
end

def check_state(number_of_finished_vms, tasks, fail)
  if number_of_finished_vms == tasks.count && tasks.count > 0
    $evm.root['ae_result'] = "ok"
  elsif fail
    $evm.root['ae_result'] = "error"
    $evm.log(:info, "*********  Provision failed  ************")
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
  create_provision_requests(args[2]['vm_name'], num_of_vms, args, type)
end

def start_provisioning
  $evm.log(:info, '*********  starting provision  ************')
  provision_request($evm.root['automation_task'].automation_request.options[:attrs][:nodes_provision], "node")
  provision_request($evm.root['automation_task'].automation_request.options[:attrs][:masters_provision], "master")
end

def provision
  tasks = tagged_tasks
  if tasks.empty?
    create_custom_tags
    tasks = tagged_tasks
  end
  $evm.root['state']                   = "provision"
  $evm.root['automation_task'].message = "Provisioning"
  $evm.log(:info, "********************** provision ***************************")
  start_provisioning if tasks.empty?
  number_of_finished_vms = 0
  fail                   = false
  $evm.log(:info, '*********  checking state of machines   ************')
  tasks.each do |prov|
    if prov.request_state.include?('finished')
      number_of_finished_vms += 1 if prov.status.include?('Ok')
      fail = true if prov.status.include?('Error')
    end
  end
  check_state(number_of_finished_vms, tasks, fail)
end

def create_custom_tags
  unless $evm.execute('category_exists?', 'miq_openstack_deploy')
    $evm.log(:info, "********************** creating deployment category ***************************")
    $evm.execute('category_create',
                 :name         => 'miq_openstack_deploy',
                 :single_value => false,
                 :description  => 'miq_openstack_deploy')
  end
  create_custom_tag("master")
  create_custom_tag("node")
end

provision
