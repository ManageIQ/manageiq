class VmOrTemplateDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    "svg/vendor-#{vendor.downcase}.svg"
  end
end
