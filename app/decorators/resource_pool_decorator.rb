class ResourcePoolDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    "100/#{vapp ? 'vapp' : 'resource_pool'}.png"
  end
end
