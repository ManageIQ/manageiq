class ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScriptDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    '100/configuration_script.png'
  end
end
