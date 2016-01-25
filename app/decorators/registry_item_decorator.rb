class RegistryItemDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    "100/#{image_name.downcase}.png"
  end
end
