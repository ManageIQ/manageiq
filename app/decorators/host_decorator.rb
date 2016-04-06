class HostDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    "svg/vendor-#{vmm_vendor_display.downcase}.svg"
  end
end
