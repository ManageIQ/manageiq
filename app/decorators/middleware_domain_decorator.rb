class MiddlewareDomainDecorator < Draper::Decorator
  delegate_all
  include MiddlewareDecoratorMixin

  def fonticon
    'pficon-domain'.freeze
  end

  # Determine the icon
  def item_image
    'middleware_domain'
  end
end
