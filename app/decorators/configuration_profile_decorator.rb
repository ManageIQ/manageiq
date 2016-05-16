class ConfigurationProfileDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    if id.nil?
      "100/folder.png"
    else
      "100/#{image_name.downcase}.png"
    end
  end
end
