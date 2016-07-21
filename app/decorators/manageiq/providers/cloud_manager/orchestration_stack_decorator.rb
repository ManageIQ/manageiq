class ManageIQ::Providers::CloudManager::OrchestrationStackDecorator < Draper::Decorator
  def fonticon
    nil
  end

  def listicon_image
    "100/orchestration_stack.png"
  end
end
