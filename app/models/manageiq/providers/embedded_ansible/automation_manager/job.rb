class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job < ManageIQ::Providers::EmbeddedAutomationManager::OrchestrationStack
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Job

  require_nested :Status

  def retire_now(requester = nil)
    update_attributes(:retirement_requester => requester)
    finish_retirement
  end

  # Intend to be called by UI to display stdout. Therefore the error message directly returned
  # instead of raising an exception.
  def raw_stdout_via_worker(userid = User.current_user, format = 'txt')
    unless MiqRegion.my_region.role_active?("embedded_ansible")
      return "Cannot get standard output of this playbook because the embedded Ansible role is not enabled"
    end

    options = {:userid => userid, :action => 'ansible_stdout'}
    queue_options = {:class_name  => self.class,
                     :method_name => 'raw_stdout',
                     :instance_id => id,
                     :args        => [format],
                     :priority    => MiqQueue::HIGH_PRIORITY,
                     :role        => 'embedded_ansible'}
    taskid = MiqTask.generic_action_with_callback(options, queue_options)
    MiqTask.wait_for_taskid(taskid)
    miq_task = MiqTask.find(taskid)
    results = miq_task.task_results || miq_task.message
    miq_task.destroy
    results
  end
end
