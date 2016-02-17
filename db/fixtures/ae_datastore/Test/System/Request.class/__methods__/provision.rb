def get_tagged_tasks()
  tasks = []
  $evm.vmdb('miq_provision_request').all.each do |prov|
    if (prov.get_tags[:deploy].include?("master_#{$evm.root['automation_task'][:id].to_s}") || prov.get_tags[:deploy].include?("node_#{$evm.root['automation_task'][:id].to_s}"))
      tasks << prov
    end
  end
  tasks
end

def create_deployment_provision_request(vm_attr, type)
  # arg1 = version
  args = ['1.1']
# arg2 = templateFields
  args << vm_attr['templateFields']
# arg3 = vmFields vm_attr['vmFields']
  args << vm_attr['vmFields']
# arg4 = requester
  args << vm_attr['requester']
# arg5 = tags
  args << {'deployment_provision' => (type + '_' + $evm.root['automation_task'][:id].to_s)}
# arg6 = additionalValues (ws_values)
  args << vm_attr['ws_values']
# arg7 = emsCustomAttributes
  args << nil
# arg8 = miqCustomAttributes
  args << nil
  request = $evm.execute('create_provision_request', *args)
  request.add_tag("deploy", type + '_' + $evm.root['automation_task'][:id].to_s)
end

def provision
  $evm.log(:info, "********************** provision ***************************")

  provision_started = false
  tasks = get_tagged_tasks
  unless tasks.empty?
    provision_started = true
  end

  unless provision_started
    $evm.log(:info, '*********  starting provision  ************')
    node_deployment = $evm.root['automation_task'].automation_request.options[:attrs][:node]
    create_deployment_provision_request(node_deployment, "node")
    master_deployment = $evm.root['automation_task'].automation_request.options[:attrs][:master]
    create_deployment_provision_request(master_deployment, "master")
  end

  requests_finished = false
  count = 0
  if provision_started
    $evm.log(:info, '*********  checking state of machines   ************')
    tasks.each do |prov|
      if prov.request_state.include?('finished') && prov.status.include?('ok')
        count = count + 1
      end
    end

  end

  if count > 1
    $evm.root['ae_result'] = 'ok'
    #need to get all needed data from the vm's ip, credentials, etc..
  else
    $evm.log(:info, '*********  Provision isnt finished retrying in 1 min   ************')
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '3.minute'
  end

end

def create_custom_tags
  # bug, have to create category all the time
  category_name = 'deploy'
  unless $evm.execute('category_exists?', category_name)
    $evm.log(:info, "********************** creating deployment category ***************************")
    $evm.execute('category_create',
                 :name => category_name,
                 :single_value => false,
                 :description => category_name)
  end
  unless $evm.execute('tag_exists?', category_name, "master_#{$evm.root['automation_task'][:id].to_s}")
    $evm.log(:info, "********************** creating tag ***************************")
    $evm.execute('tag_create',
                 category_name,
                 :name => "master_#{$evm.root['automation_task'][:id].to_s}",
                 :description => "master_#{$evm.root['automation_task'][:id].to_s}")
  end
  unless $evm.execute('tag_exists?', category_name, "node_#{$evm.root['automation_task'][:id].to_s}")
    $evm.log(:info, "********************** creating tag ***************************")
    $evm.execute('tag_create',
                 category_name,
                 :name => "node_#{$evm.root['automation_task'][:id].to_s}",
                 :description => "node_#{$evm.root['automation_task'][:id].to_s}")
  end
end

create_custom_tags
provision






