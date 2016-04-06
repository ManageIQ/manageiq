class ExtManagementSystemDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    "100/vendor-#{image_name}.png"
  end
end
