def delete()
  $evm.log(:info, "********************** delete ansible files ***************************")
  $evm.root['automation_task'].message = "Delete_ansible_files"
  FileUtils.rm %w( master_inventory.yaml to_send_inventory.yaml deploy_book.yaml local_book.yaml )

end

delete()