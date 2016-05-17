INVENTORY_FILE = 'inventory.yaml'.freeze
RHEL_SUBSCRIBE_INVENTORY = 'rhel_subscribe_inventory.yaml'.freeze

def process_exists?(process_pid)
  begin
    Process.kill(0, process_pid) == 1
  rescue
    false
  end
end

def cleanup
  $evm.log(:info, "********************** #{$evm.root['ae_state']} ***************************")
  begin
    if File.exist?(INVENTORY_FILE)
      $evm.log(:info, "deleting #{INVENTORY_FILE}")
      system "sudo rm #{INVENTORY_FILE}"
    end
    if File.exist?(RHEL_SUBSCRIBE_INVENTORY)
      $evm.log(:info, "deleting #{RHEL_SUBSCRIBE_INVENTORY}")
      system "sudo rm #{RHEL_SUBSCRIBE_INVENTORY}"
    end
    if process_exists?($evm.root['agent_pid'])
      system({"SSH_AGENT_PID" => $evm.root['agent_pid']}, "(ssh-agent -k) &> /dev/null")
      unless process_exists?($evm.root['agent_pid'])
        $evm.log(:info, "State: #{$evm.root['ae_state']} | Couldn't clean up ssh-agent process with pid:#{$evm.root['agent_pid']}")
      end
    end
    $evm.root['ae_result'] = "ok"
    $evm.root['automation_task'].message = "successful deployment cleanup"
  rescue Exception => e
    $evm.log(:info, e)
    $evm.root['ae_result'] = "error"
    $evm.root['automation_task'].message = e.message
  ensure
    $evm.log(:info, "State: #{$evm.root['ae_state']} | Result: #{$evm.root['ae_result']} "\
             "| Message: #{$evm.root['automation_task'].message}")
  end
end

cleanup
