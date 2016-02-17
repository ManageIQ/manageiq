def pre_deployment()
  $evm.log(:info, "********************** master pre deployment ***************************")
  system "ansible-playbook extras/playbooks/deploy_book.yaml -i master_inventory.yaml"
end

pre_deployment()