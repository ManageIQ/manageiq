class ExtManagementSystemDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    "svg/vendor-#{image_name}.svg"
  end
end
