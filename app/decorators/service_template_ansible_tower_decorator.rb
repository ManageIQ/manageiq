class ServiceTemplateAnsibleTowerDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    "/pictures/#{picture.basename}" if try(:picture)
  end
end
