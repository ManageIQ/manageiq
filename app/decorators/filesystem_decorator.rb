class FilesystemDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    "ico/win/#{image_name.downcase}.ico"
  end
end
