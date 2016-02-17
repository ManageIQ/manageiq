def delete_ansible_files(ansible_files)
  $evm.root['Phase'] = "delete_ansible_files"
  $evm.log(:info, "********************** delete ansible files ***************************")

  ansible_files.each do |f|
    begin
      File.delete(f)
    rescue
      $evm.root['ae_result'] = "error"
      $evm.root['Message'] = "failed deleting Ansible files"
      return
    end
  end
  $evm.root['ae_result'] = "ok"
  $evm.root['Message'] = "successfuly deleted Ansible files"
end

delete_ansible_files([$evm.root['deploy_book_path'], $evm.root['inventory_file_path'],
                      $evm.root['master_inventory_file_path']])