INVENTORY_FILE = 'inventory.yaml'.freeze
RHEL_SUBSCRIBE_INVENTORY = 'rhel_subscribe_inventory.yaml'.freeze

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
    $evm.root['ae_result'] = "ok"
    $evm.root['automation_task'].message = "successful deployment cleanup"
  rescue => e
    $evm.root['ae_result'] = "error"
    $evm.root['automation_task'].message = e.message
  ensure
    $evm.log(:info, "State: #{$evm.root['ae_state']} | Result: #{$evm.root['ae_result']} "\
             "| Message: #{$evm.root['automation_task'].message}")
  end
end

cleanup
