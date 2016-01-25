class MiqEventDefinitionDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    "100/event-#{name.downcase}.png"
  end
end
