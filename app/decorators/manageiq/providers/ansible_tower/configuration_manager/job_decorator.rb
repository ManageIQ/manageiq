class ManageIQ::Providers::AnsibleTower::ConfigurationManager::JobDecorator < Draper::Decorator
  delegate_all

  def fonticon
    'product product-orchestration_stack'.freeze
  end

  def listicon_image
    '100/orchestration_stack.png'
  end
end
