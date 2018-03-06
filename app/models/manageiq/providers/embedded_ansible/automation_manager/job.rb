class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job < ManageIQ::Providers::EmbeddedAutomationManager::OrchestrationStack
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Job

  require_nested :Status

  # Intend to be called by UI to display stdout. The stdout is stored in MiqTask#task_results or #message if error
  # Since the task_results may contain a large block of data, it is desired to remove the task upon receiving the data
  def raw_stdout_via_worker(userid, format = 'txt')
    unless MiqRegion.my_region.role_active?("embedded_ansible")
      msg = "Cannot get standard output of this playbook because the embedded Ansible role is not enabled"
      return MiqTask.create(
        :name    => 'ansible_stdout',
        :userid  => userid || 'system',
        :state   => MiqTask::STATE_FINISHED,
        :status  => MiqTask::STATUS_ERROR,
        :message => msg
      ).id
    end

    options = {:userid => userid || 'system', :action => 'ansible_stdout'}
    queue_options = {:class_name  => self.class,
                     :method_name => 'raw_stdout',
                     :instance_id => id,
                     :args        => [format],
                     :priority    => MiqQueue::HIGH_PRIORITY,
                     :role        => 'embedded_ansible'}
    MiqTask.generic_action_with_callback(options, queue_options)
  end
end
