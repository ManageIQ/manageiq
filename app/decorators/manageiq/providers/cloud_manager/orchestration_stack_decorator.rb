class ManageIQ::Providers::CloudManager::OrchestrationStackDecorator < Draper::Decorator
  def fonticon
    'product product-orchestration_stack'.freeze
  end

  def listicon_image
    "100/orchestration_stack.png"
  end
end
