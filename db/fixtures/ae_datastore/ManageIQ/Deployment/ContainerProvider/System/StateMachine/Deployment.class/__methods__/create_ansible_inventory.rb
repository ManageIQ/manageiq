require 'net/ssh'

INVENTORY_FILE = 'inventory.yaml'.freeze
RHEL_SUBSCRIBE_INVENTORY = 'rhel_subscribe_inventory.yaml'.freeze

def create_ansible_inventory_file(subscribe = false)
  if subscribe
    template = $evm.root['automation_task'].automation_request.options[:attrs][:rhel_subscribe_inventory]
    inv_file_path = RHEL_SUBSCRIBE_INVENTORY
  else
    $evm.log(:info, "********************** #{$evm.root['ae_state']} ***************************")
    template = $evm.root['masters'] = $evm.root['automation_task'].automation_request.options[:attrs][:inventory]
    inv_file_path = INVENTORY_FILE
  end
  begin
    $evm.log(:info, "creating #{inv_file_path}")
    File.open(inv_file_path, 'w') do |f|
      f.write(template)
    end
    $evm.root['ae_result'] = "ok"
    $evm.root['automation_task'].message = "successfully created #{inv_file_path}"
  rescue StandardError => e
    $evm.root['ae_result'] = "error"
    $evm.root['automation_task'].message = "failed to create #{inv_file_path}: " + e
  end
end

create_ansible_inventory_file
# check if an additional inventory file is needed for handling rhel subscriptions
begin
  Net::SSH.start($evm.root['deployment_master'], $evm.root['user'], :paranoid => false, :forward_agent => true,
                 :key_data => $evm.root['private_key']) do |ssh|
    create_ansible_inventory_file(true) if ssh.exec!("cat /etc/redhat-release").include?("Red Hat Enterprise Linux")
  end
rescue
  $evm.root['ae_result'] = "error"
  $evm.root['automation_task'].message = "Cannot connect to deployment master " \
                                         "(#{$evm.root['deployment_master']}) via ssh"
end
$evm.log(:info, "State: #{$evm.root['ae_state']} | Result: #{$evm.root['ae_result']} "\
         "| Message: #{$evm.root['automation_task'].message}")
