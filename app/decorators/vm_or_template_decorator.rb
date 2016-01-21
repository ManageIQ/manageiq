class VmOrTemplateDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    "100/vendor-#{vendor.downcase}.png"
  end
end
