class  ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScriptDecorator  < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    "100/cm_job_template.png"
  end
end
