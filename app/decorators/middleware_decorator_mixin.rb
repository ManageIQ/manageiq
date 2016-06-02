module MiddlewareDecoratorMixin
  def listicon_image
    prefix = "100/"
    suffix = ".png"
    prefix + item_image + suffix
  end
end
