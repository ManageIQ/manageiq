require 'net/scp'

module MiqAeMethodService
  class MiqAeServiceContainerDeployment < MiqAeServiceModelBase
    expose :run_playbook_command
    expose :analyze_ansible_output
    expose :provision_vms_status
    expose :find_vm_by_type
    expose :assign_container_deployment_nodes
    expose :assign_container_deployment_node
    expose :provisioned_ips_set?
    expose :roles_addresses
    expose :generate_ansible_yaml
    expose :generate_ansible_inventory_for_subscription
    expose :check_connection
    expose :subscribe_deployment_master
    expose :subscribe_cluster
    expose :provision_started?
    expose :nodes_subscription_needed?
    expose :ssh_user
    expose :add_automation_task
    expose :perform_scp
    expose :perform_agent_commands
    expose :playbook_running?
    expose :add_deployment_provider
  end
end
