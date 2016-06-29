class MiddlewareJmsDecorator < Draper::Decorator
  delegate_all
  include MiddlewareDecoratorMixin

  def fonticon
    'fa fa-exchange'.freeze
  end

  # Determine the icon
  def item_image
    'middleware_jms'
  end
end
