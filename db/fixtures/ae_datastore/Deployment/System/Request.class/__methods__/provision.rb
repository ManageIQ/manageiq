def get_custom_tag(type)
  type + "_#{$evm.root['automation_task'][:id]}"
end

def get_tagged_tasks
  tasks = []
  $evm.vmdb('miq_provision_request').all.each do |prov|
    if prov.get_tags[:deploy] && (prov.get_tags[:deploy].include?(get_custom_tag("master")) || prov.get_tags[:deploy].include?(get_custom_tag("node")))
      tasks << prov
    end
  end
  tasks
end

def create_deployment_provision_request(vm_attr, type)
  num_of_vms = vm_attr['number_of_vms'].to_i
  # arg1 = version
  args       = ['1.1']
  # arg2 = templateFields
  args << vm_attr['templateFields']
  # arg3 = vmFields vm_attr['vmFields']
  args << vm_attr['vmFields']
  # arg4 = requester
  args << vm_attr['requester']
  # arg5 = tags
  args << nil
  # arg6 = additionalValues (ws_values)
  args << vm_attr['ws_values']
  # arg7 = emsCustomAttributes
  args << nil
  # arg8 = miqCustomAttributes
  args << nil
  vm_base_name = args[2]['vm_name']
  (1..num_of_vms).each do |num|
    args[2]['vm_name'] = vm_base_name + "_" + num.to_s
    request            = $evm.execute('create_provision_request', *args)
    request.add_tag("deploy", type + '_' + $evm.root['automation_task'][:id].to_s)
  end
end

def provision
  # $evm.root['automation_task'].message = "Provisioning"
  $evm.log(:info, "********************** provision ***************************")

  provision_started = false
  tasks             = get_tagged_tasks
  unless tasks.empty?
    provision_started = true
  end

  unless provision_started
    $evm.log(:info, '*********  starting provision  ************')
    node_deployment = $evm.root['automation_task'].automation_request.options[:attrs][:nodes_provision]
    create_deployment_provision_request(node_deployment, "node")
    master_deployment = $evm.root['automation_task'].automation_request.options[:attrs][:masters_provision]
    create_deployment_provision_request(master_deployment, "master")
  end

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
  if number_of_finished_vms == tasks.count && tasks.count > 0
    $evm.root['ae_result'] = "ok"
  elsif fail
    $evm.root['ae_result'] = "error"
  else
    $evm.log(:info, "*********  Provision isnt finished re-trying in 1 min  #{message} ************")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
  end
end

def create_custom_tags
  # bug, have to create category all the time
  category_name = 'deploy'
  unless $evm.execute('category_exists?', category_name)
    $evm.log(:info, "********************** creating deployment category ***************************")
    $evm.execute('category_create',
                 :name         => category_name,
                 :single_value => false,
                 :description  => category_name)
  end
  unless $evm.execute('tag_exists?', category_name, "master_#{$evm.root['automation_task'][:id]}")
    $evm.log(:info, "********************** creating tag ***************************")
    $evm.execute('tag_create',
                 category_name,
                 :name        => "master_#{$evm.root['automation_task'][:id]}",
                 :description => "master_#{$evm.root['automation_task'][:id]}")
  end
  unless $evm.execute('tag_exists?', category_name, "node_#{$evm.root['automation_task'][:id]}")
    $evm.log(:info, "********************** creating tag ***************************")
    $evm.execute('tag_create',
                 category_name,
                 :name        => "node_#{$evm.root['automation_task'][:id]}",
                 :description => "node_#{$evm.root['automation_task'][:id]}")
  end
end

create_custom_tags
provision
