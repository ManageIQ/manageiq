class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job < ManageIQ::Providers::EmbeddedAutomationManager::OrchestrationStack
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Job
  include CiFeatureMixin

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

    super(userid, format, 'embedded_ansible')
  end

  def retireable?
    false
  end
end
