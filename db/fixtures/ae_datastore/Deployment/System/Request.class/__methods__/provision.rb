def get_custom_tag(type)
  type + "_#{$evm.root['automation_task'][:id]}"
end

def create_custom_tag(name)
  unless $evm.execute('tag_exists?', 'deploy', "#{name}_#{$evm.root['automation_task'][:id]}")
    $evm.log(:info, "********************** creating tag ***************************")
    $evm.execute('tag_create',
                 'deploy',
                 :name        => "#{name}_#{$evm.root['automation_task'][:id]}",
                 :description => "#{name}_#{$evm.root['automation_task'][:id]}")
  end
end

def tagged_tasks
  tasks = []
  $evm.vmdb('miq_provision_request').all.each do |prov|
    next unless prov.get_tags[:deploy] &&
                (prov.get_tags[:deploy].include?(get_custom_tag("master")) ||
                  prov.get_tags[:deploy].include?(get_custom_tag("node")))
    tasks << prov
  end
  tasks
end

def create_provision_requests(vm_base_name, num_of_vms, args, type)
  (1..num_of_vms).each do |num|
    args[2]['vm_name'] = vm_base_name + "_" + num.to_s
    request            = $evm.execute('create_provision_request', *args)
    request.add_tag("deploy", type + '_' + $evm.root['automation_task'][:id].to_s)
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

def create_deployment_provision_request(vm_attr, type)
  num_of_vms = vm_attr['number_of_vms'].to_i
  args       = ['1.1']
  args << vm_attr['templateFields']
  args << vm_attr['vmFields']
  args << vm_attr['requester']
  args << nil
  args << vm_attr['ws_values']
  args << nil
  args << nil
  vm_base_name = args[2]['vm_name']
  create_provision_requests(vm_base_name, num_of_vms, args, type)
end

def start_provisioing
  $evm.log(:info, '*********  starting provision  ************')
  # node_deployment = $evm.root['automation_task'].automation_request.options[:attrs][:nodes_provision]
  # create_deployment_provision_request(node_deployment, "node")
  master_deployment = $evm.root['automation_task'].automation_request.options[:attrs][:masters_provision]
  create_deployment_provision_request(master_deployment, "master")
end

def provision
  $evm.root['automation_task'].message = "Provisioning"
  $evm.log(:info, "********************** provision ***************************")
  provision_started = false
  tasks             = tagged_tasks
  provision_started = true unless tasks.empty?
  start_provisioing unless provision_started
  number_of_finished_vms = 0
  fail                   = false
  if provision_started
    $evm.log(:info, '*********  checking state of machines   ************')
    tasks.each do |prov|
      if prov.request_state.include?('finished') && prov.status.include?('Ok')
        number_of_finished_vms += 1
      elsif prov.request_state.include?('finished') && prov.status.include?('Error')
        fail = true
      end
    end
  end
  check_state(number_of_finished_vms, tasks, fail)
end

def create_custom_tags
  unless $evm.execute('category_exists?', 'deploy')
    $evm.log(:info, "********************** creating deployment category ***************************")
    $evm.execute('category_create',
                 :name         => 'deploy',
                 :single_value => false,
                 :description  => 'deploy')
  end
  create_custom_tag("master")
  create_custom_tag("node")
end

create_custom_tags
provision
