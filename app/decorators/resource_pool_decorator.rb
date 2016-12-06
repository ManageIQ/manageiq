class ResourcePoolDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    quadicon_image_path
  end

  def quadicon_image_path
    "100/#{quadicon_image_name}.png"
  end

  def quadicon_image_name
    vapp ? 'vapp' : 'resource_pool'
  end
end
