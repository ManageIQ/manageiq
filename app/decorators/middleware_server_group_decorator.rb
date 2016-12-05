class MiddlewareServerGroupDecorator < Draper::Decorator
  delegate_all
  include MiddlewareDecoratorMixin

  def fonticon
    'pficon-server-group'.freeze
  end

  # Determine the icon
  def item_image
    'middleware_server_group'
  end
end
