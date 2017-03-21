module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Job::Status
  def succeeded?
    status.casecmp("successful").zero?
  end

  def failed?
    status.casecmp("failed").zero?
  end

  def canceled?
    status.casecmp("canceled").zero?
  end

  def normalized_status
    return ['transient', reason || status] unless completed?

    if succeeded?
      ['create_complete', reason || 'OK']
    elsif deleted?
      ['delete_complete', reason || 'Job was deleted']
    elsif canceled?
      ['create_canceled', reason || 'Job launching was canceled']
    elsif updated?
      ['update_complete', reason || 'OK']
    else
      ['failed', reason || 'Job launching failed']
    end
  end
end
