class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job < ManageIQ::Providers::EmbeddedAutomationManager::OrchestrationStack
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Job

  require_nested :Status

  def retire_now(requester = nil)
    update_attributes(:retirement_requester => requester)
    finish_retirement
  end

  def self.run(options, userid = nil)
    userid ||= 'system'
    info = options[:config_info]
    playbook = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook.find(info[:playbook_id])
    playbook.queue_runner(userid, options)
  end
end
