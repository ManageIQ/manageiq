def pre_deployment()
  $evm.root['Phase'] = "check ssh"
  $evm.log(:info, "********************** master pre deployment ***************************")
  system "ansible-playbook extras/playbooks/deploy_book.yaml -i master_inventory.yaml"

  #TODO: think how to verify pre-deployment (poll from log)
  $evm.root['ae_result'] = "ok"
  $evm.root['Message'] = "successfuly pre-deployed"
end

pre_deployment()