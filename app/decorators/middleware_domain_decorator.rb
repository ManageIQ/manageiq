class MiddlewareDomainDecorator < Draper::Decorator
  delegate_all
  include MiddlewareDecoratorMixin

  def fonticon
    'domain'.freeze
  end

  # Determine the icon
  def item_image
    'middleware_domain'
  end
end
